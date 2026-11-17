package io.github.michelo1927.scrl_video

import android.content.Context
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.ByteArrayOutputStream
import java.nio.ByteOrder
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** Audio di un video in PCM s16 stereo a 44,1 kHz (come `read_audio` del desktop). */
object LettoreAudio {
    const val FREQUENZA = 44100

    /**
     * Audio da [inizio] a [fine] secondi; se è più corto del taglio si completa col silenzio, così il giro
     * successivo resta a tempo. Null se il video non ha audio.
     */
    fun leggi(contesto: Context, sorgente: String, inizio: Double, fine: Double): ByteArray? {
        val e = ScrlVideoPlugin.apriEstrattore(contesto, sorgente)
        var dec: MediaCodec? = null
        try {
            val traccia = ScrlVideoPlugin.tracciaDi(e, "audio/") ?: return null
            e.selectTrack(traccia)
            val formato = e.getTrackFormat(traccia)
            val inizioUs = max(0L, e.sampleTime)
            e.seekTo(inizioUs + (max(0.0, inizio) * 1_000_000).toLong(), MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
            val d = MediaCodec.createDecoderByType(formato.getString(MediaFormat.KEY_MIME)!!)
            dec = d
            d.configure(formato, null, null, 0)
            d.start()
            var canali = formato.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            var frequenza = formato.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var virgola = false
            val pcm = ByteArrayOutputStream()
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
                val ft = (info.presentationTimeUs - inizioUs) / 1_000_000.0
                if (info.size > 0) {
                    if (primoT == null) primoT = ft
                    val b = d.getOutputBuffer(o)!!.order(ByteOrder.LITTLE_ENDIAN)
                    b.position(info.offset)
                    b.limit(info.offset + info.size)
                    if (virgola) {
                        val fb = b.asFloatBuffer()
                        val tmp = ByteArray(fb.remaining() * 2)
                        var k = 0
                        while (fb.hasRemaining()) {
                            val s = (fb.get().coerceIn(-1f, 1f) * 32767f).roundToInt()
                            tmp[k++] = (s and 0xFF).toByte()
                            tmp[k++] = (s shr 8).toByte()
                        }
                        pcm.write(tmp)
                    } else {
                        val tmp = ByteArray(info.size)
                        b.get(tmp)
                        pcm.write(tmp)
                    }
                }
                d.releaseOutputBuffer(o, false)
                if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0 || ft > fine + 0.5) break
            }
            val t0 = primoT ?: return null
            val stereo = aStereo44(pcm.toByteArray(), canali, frequenza)
            val salta = max(0, ((inizio - t0) * FREQUENZA).roundToInt()) * 4
            val prendi = max(0, ((fine - inizio) * FREQUENZA).roundToInt()) * 4
            val out = ByteArray(prendi)
            if (salta < stereo.size) System.arraycopy(stereo, salta, out, 0, min(prendi, stereo.size - salta))
            return out
        } finally {
            try {
                dec?.stop()
            } catch (_: Throwable) {
            }
            dec?.release()
            e.release()
        }
    }

    /** PCM s16 con [canali] canali a [frequenza] Hz → stereo a 44,1 kHz (interpolazione lineare). */
    private fun aStereo44(pcm: ByteArray, canali: Int, frequenza: Int): ByteArray {
        val n = pcm.size / (2 * canali)
        fun campione(i: Int, c: Int): Int {
            val k = (i * canali + min(c, canali - 1)) * 2
            return (pcm[k].toInt() and 0xFF) or (pcm[k + 1].toInt() shl 8)
        }
        if (n == 0) return ByteArray(0)
        val m = (n.toLong() * FREQUENZA / frequenza).toInt()
        val out = ByteArray(m * 4)
        val passo = frequenza.toDouble() / FREQUENZA
        for (j in 0 until m) {
            val x = j * passo
            val i0 = min(n - 1, x.toInt())
            val i1 = min(n - 1, i0 + 1)
            val f = x - i0
            for (c in 0 until 2) {
                val s = (campione(i0, c) * (1 - f) + campione(i1, c) * f).roundToInt()
                out[j * 4 + c * 2] = (s and 0xFF).toByte()
                out[j * 4 + c * 2 + 1] = (s shr 8).toByte()
            }
        }
        return out
    }
}
