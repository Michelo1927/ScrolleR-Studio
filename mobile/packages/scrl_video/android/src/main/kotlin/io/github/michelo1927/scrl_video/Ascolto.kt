package io.github.michelo1927.scrl_video

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.PlaybackParams
import java.nio.ByteOrder
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.roundToLong

/**
 * Audio da ascoltare nella schermata Sottotitoli (`read_audio_mono` e `_Playback` del desktop): tutto l'audio del
 * video in PCM s16 mono a 24 kHz, allineato al secondo 0 del video, suonato con un AudioTrack. L'orologio è
 * l'audio stesso (i campioni già suonati), così testo e voce non si staccano; la velocità rallenta senza
 * cambiare il tono della voce.
 */
class Ascolto private constructor(val pcm: ShortArray) {
    private var traccia: AudioTrack? = null
    private var scrittore: Thread? = null

    @Volatile
    private var fermo = true

    @Volatile
    private var scritti = 0

    /** Secondo del video da cui è partita la riproduzione in corso. */
    private var t0 = 0.0
    private var velocita = 1.0f

    val durata: Double get() = pcm.size / FREQUENZA.toDouble()

    /** Suona dal secondo [t] alla velocità [v] (1, 0,75, 0,5…), fino alla fine o a [ferma]. */
    fun suona(t: Double, v: Double) {
        ferma()
        velocita = v.toFloat()
        val inizio = (t * FREQUENZA).roundToInt().coerceIn(0, pcm.size)
        t0 = inizio / FREQUENZA.toDouble()
        if (inizio >= pcm.size) return
        val minimo = AudioTrack.getMinBufferSize(
            FREQUENZA,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        val a = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(FREQUENZA)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build(),
            )
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setBufferSizeInBytes(max(minimo, FREQUENZA / 5 * 2))
            .build()
        a.playbackParams = PlaybackParams().setSpeed(velocita).setPitch(1.0f)
        traccia = a
        fermo = false
        scritti = 0
        a.play()
        val th = Thread {
            var i = inizio
            while (!fermo && i < pcm.size) {
                val n = a.write(pcm, i, min(PEZZO, pcm.size - i), AudioTrack.WRITE_BLOCKING)
                if (n <= 0) break
                i += n
                scritti += n
            }
            // A fine audio si lascia suonare quello che è già nel buffer
            if (!fermo) {
                try {
                    a.stop()
                } catch (_: IllegalStateException) {
                }
            }
        }
        th.name = "scrl-ascolto"
        scrittore = th
        th.start()
    }

    /** Secondo del video che si sta sentendo; `suona` è falso a riproduzione ferma o finita. */
    fun tempo(): Map<String, Any> {
        val a = traccia ?: return mapOf("t" to t0, "suona" to false)
        val testa = try {
            a.playbackHeadPosition
        } catch (_: IllegalStateException) {
            0
        }
        val t = min(durata, t0 + testa / FREQUENZA.toDouble())
        val finito = scrittore?.isAlive != true && testa >= scritti
        return mapOf("t" to t, "suona" to (!fermo && !finito))
    }

    /** Cambia la velocità senza fermarsi. */
    fun cambiaVelocita(v: Double) {
        velocita = v.toFloat()
        try {
            traccia?.playbackParams = PlaybackParams().setSpeed(velocita).setPitch(1.0f)
        } catch (_: IllegalStateException) {
        }
    }

    /** Ferma e restituisce il secondo a cui si è arrivati. */
    fun ferma(): Double {
        val a = traccia ?: return t0
        val t = tempo()["t"] as Double
        fermo = true
        try {
            a.pause()
            a.flush()
        } catch (_: IllegalStateException) {
        }
        a.release()
        scrittore?.join(500)
        scrittore = null
        traccia = null
        t0 = t
        return t
    }

    /** PCM in byte (little-endian), per l'inviluppo e le pause calcolati dal motore. */
    fun byte(): ByteArray {
        val out = ByteArray(pcm.size * 2)
        for (k in pcm.indices) {
            val s = pcm[k].toInt()
            out[2 * k] = (s and 0xFF).toByte()
            out[2 * k + 1] = (s shr 8).toByte()
        }
        return out
    }

    companion object {
        const val FREQUENZA = 24000
        private const val PEZZO = FREQUENZA / 20

        /** Legge tutto l'audio del video; null se non ne ha. */
        fun apri(contesto: Context, sorgente: String): Ascolto? {
            val e = ScrlVideoPlugin.apriEstrattore(contesto, sorgente)
            var dec: MediaCodec? = null
            try {
                // Il secondo 0 è il primo fotogramma del video (come in LettoreFotogrammi)
                val video = ScrlVideoPlugin.tracciaDi(e, "video/")
                val audio = ScrlVideoPlugin.tracciaDi(e, "audio/") ?: return null
                var zeroUs: Long? = null
                if (video != null) {
                    e.selectTrack(video)
                    zeroUs = max(0L, e.sampleTime)
                    e.unselectTrack(video)
                }
                e.selectTrack(audio)
                e.seekTo(0, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                val zero = zeroUs ?: max(0L, e.sampleTime)
                val formato = e.getTrackFormat(audio)
                val d = MediaCodec.createDecoderByType(formato.getString(MediaFormat.KEY_MIME)!!)
                dec = d
                d.configure(formato, null, null, 0)
                d.start()
                var canali = formato.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                var frequenza = formato.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                var virgola = false
                val mono = Ricampionatore()
                var primoT: Double? = null
                val info = MediaCodec.BufferInfo()
                var fineIngresso = false
                var vuoti = 0
                while (true) {
                    if (!fineIngresso) {
                        val i = d.dequeueInputBuffer(5_000)
                        if (i >= 0) {
                            val n = e.readSampleData(d.getInputBuffer(i)!!, 0)
                            if (n < 0) {
                                d.queueInputBuffer(i, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                fineIngresso = true
                            } else {
                                d.queueInputBuffer(i, 0, n, e.sampleTime, 0)
                                e.advance()
                            }
                        }
                    }
                    val o = d.dequeueOutputBuffer(info, 5_000)
                    if (o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        val f = d.outputFormat
                        canali = f.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                        frequenza = f.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        virgola = f.containsKey(MediaFormat.KEY_PCM_ENCODING) &&
                            f.getInteger(MediaFormat.KEY_PCM_ENCODING) == AudioFormat.ENCODING_PCM_FLOAT
                        continue
                    }
                    if (o < 0) {
                        if (++vuoti > 400) break
                        continue
                    }
                    vuoti = 0
                    if (info.size > 0) {
                        if (primoT == null) primoT = (info.presentationTimeUs - zero) / 1_000_000.0
                        mono.passo = frequenza.toDouble() / FREQUENZA
                        val b = d.getOutputBuffer(o)!!.order(ByteOrder.LITTLE_ENDIAN)
                        b.position(info.offset)
                        b.limit(info.offset + info.size)
                        if (virgola) {
                            val fb = b.asFloatBuffer()
                            while (fb.remaining() >= canali) {
                                var s = 0f
                                for (c in 0 until canali) s += fb.get().coerceIn(-1f, 1f) * 32767f
                                mono.aggiungi(s / canali)
                            }
                        } else {
                            val sb = b.asShortBuffer()
                            while (sb.remaining() >= canali) {
                                var s = 0f
                                for (c in 0 until canali) s += sb.get()
                                mono.aggiungi(s / canali)
                            }
                        }
                    }
                    d.releaseOutputBuffer(o, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) break
                }
                val t = primoT ?: return null
                // Audio che parte dopo il video: silenzio davanti; che parte prima: si taglia
                val sposta = (t * FREQUENZA).roundToLong().toInt()
                val dati = mono.risultato()
                val pcm = if (sposta >= 0) {
                    ShortArray(sposta + dati.size).also { System.arraycopy(dati, 0, it, sposta, dati.size) }
                } else {
                    dati.copyOfRange(min(-sposta, dati.size), dati.size)
                }
                return Ascolto(pcm)
            } finally {
                try {
                    dec?.stop()
                } catch (_: Throwable) {
                }
                dec?.release()
                e.release()
            }
        }
    }
}

/** Da una frequenza qualsiasi a 24 kHz con l'interpolazione lineare, un campione alla volta. */
private class Ricampionatore {
    var passo = 1.0
    private var dati = ShortArray(1 shl 16)
    private var n = 0
    private var visti = 0L
    private var prec = 0f

    /** Posizione (in campioni d'ingresso) del prossimo campione d'uscita. */
    private var x = 0.0

    fun aggiungi(s: Float) {
        while (x <= visti) {
            val v = if (visti == 0L) s else prec + (s - prec) * (x - (visti - 1)).toFloat()
            if (n == dati.size) dati = dati.copyOf(dati.size * 2)
            dati[n++] = v.roundToInt().coerceIn(-32768, 32767).toShort()
            x += passo
        }
        prec = s
        visti++
    }

    fun risultato(): ShortArray = dati.copyOf(n)
}
