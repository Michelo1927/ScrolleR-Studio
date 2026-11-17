package io.github.michelo1927.scrl_video

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.nio.ByteBuffer
import kotlin.math.max
import kotlin.math.min

/**
 * MP4 H.264 + AAC con i codificatori del telefono (come `Mp4Writer` del desktop): i fotogrammi RGBA
 * arrivano in ordine, l'audio PCM s16 stereo 44,1 kHz (già mescolato) tutto all'apertura e si scrive
 * man mano, a tempo coi fotogrammi.
 */
class ScrittoreMp4(
    private val percorso: String,
    private val larghezza: Int,
    private val altezza: Int,
    private val fps: Int,
    private val audio: ByteArray?,
) {
    private val muxer = MediaMuxer(percorso, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    private val video: MediaCodec
    private val codAudio: MediaCodec?
    private var tracciaVideo = -1
    private var tracciaAudio = -1
    private var avviato = false
    private var chiuso = false
    private val inAttesa = ArrayList<Triple<Boolean, ByteArray, MediaCodec.BufferInfo>>()
    private val info = MediaCodec.BufferInfo()
    private var fotogrammi = 0L
    private var audioScritto = 0 // Byte di PCM già passati al codificatore
    private var fineVideo = false
    private var fineAudio = false
    private var audioEosInviato = false

    init {
        val fv = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, larghezza, altezza)
        fv.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible)
        // Circa 0,12 bit per pixel: 1080×1440 a 30 fps ≈ 5,6 Mbit/s
        val bitrate = min(20_000_000, max(2_000_000, (larghezza.toLong() * altezza * fps * 12 / 100).toInt()))
        fv.setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
        fv.setInteger(MediaFormat.KEY_FRAME_RATE, fps)
        fv.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        fv.setInteger(MediaFormat.KEY_COLOR_STANDARD, MediaFormat.COLOR_STANDARD_BT709)
        fv.setInteger(MediaFormat.KEY_COLOR_RANGE, MediaFormat.COLOR_RANGE_LIMITED)
        fv.setInteger(MediaFormat.KEY_COLOR_TRANSFER, MediaFormat.COLOR_TRANSFER_SDR_VIDEO)
        val nome = MediaCodecList(MediaCodecList.REGULAR_CODECS).findEncoderForFormat(fv)
        if (nome == null) {
            muxer.release()
            File(percorso).delete()
            throw IllegalStateException("Nessun codificatore H.264 per ${larghezza}×$altezza")
        }
        video = MediaCodec.createByCodecName(nome)
        var a: MediaCodec? = null
        try {
            video.configure(fv, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            video.start()
            if (audio != null && audio.isNotEmpty()) {
                val fa = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, LettoreAudio.FREQUENZA, 2)
                fa.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                fa.setInteger(MediaFormat.KEY_BIT_RATE, 192_000)
                fa.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
                a = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
                a.configure(fa, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                a.start()
            }
        } catch (t: Throwable) {
            a?.release()
            video.release()
            muxer.release()
            File(percorso).delete()
            throw t
        }
        codAudio = a
        fineAudio = a == null
    }

    fun aggiungi(rgba: ByteArray) {
        require(rgba.size >= larghezza * altezza * 4) { "Fotogramma troppo piccolo" }
        var i: Int
        while (true) {
            i = video.dequeueInputBuffer(10_000)
            if (i >= 0) break
            svuota(false)
        }
        val img = video.getInputImage(i) ?: throw IllegalStateException("Il codificatore non accetta immagini YUV")
        try {
            scriviYuv(rgba, img)
        } finally {
            img.close()
        }
        val pts = fotogrammi * 1_000_000L / fps
        video.queueInputBuffer(i, 0, larghezza * altezza * 3 / 2, pts, 0)
        fotogrammi++
        scriviAudioFinoA(fotogrammi.toDouble() / fps, false)
        svuota(false)
    }

    /** RGBA → YUV 4:2:0 BT.709 a gamma limitata, sui piani dell'immagine del codificatore (I420 o NV12). */
    private fun scriviYuv(rgba: ByteArray, img: android.media.Image) {
        val w = larghezza
        val h = altezza
        val pY = img.planes[0]
        val pU = img.planes[1]
        val pV = img.planes[2]
        val bY = pY.buffer
        val riga = ByteArray(w)
        for (y in 0 until h) {
            var s = y * w * 4
            for (x in 0 until w) {
                val r = rgba[s].toInt() and 0xFF
                val g = rgba[s + 1].toInt() and 0xFF
                val b = rgba[s + 2].toInt() and 0xFF
                riga[x] = (((47 * r + 157 * g + 16 * b + 128) shr 8) + 16).toByte()
                s += 4
            }
            bY.position(y * pY.rowStride)
            bY.put(riga, 0, w)
        }
        val cw = w / 2
        val ch = h / 2
        val rigaU = ByteArray(cw)
        val rigaV = ByteArray(cw)
        val bU = pU.buffer
        val bV = pV.buffer
        for (cy in 0 until ch) {
            for (cx in 0 until cw) {
                // Media del blocco 2×2
                var r = 0
                var g = 0
                var b = 0
                for (dy in 0..1) for (dx in 0..1) {
                    val s = ((cy * 2 + dy) * w + cx * 2 + dx) * 4
                    r += rgba[s].toInt() and 0xFF
                    g += rgba[s + 1].toInt() and 0xFF
                    b += rgba[s + 2].toInt() and 0xFF
                }
                r = (r + 2) shr 2
                g = (g + 2) shr 2
                b = (b + 2) shr 2
                rigaU[cx] = (((-26 * r - 87 * g + 112 * b + 128) shr 8) + 128).toByte()
                rigaV[cx] = (((112 * r - 102 * g - 10 * b + 128) shr 8) + 128).toByte()
            }
            scriviRigaCroma(bU, cy * pU.rowStride, pU.pixelStride, rigaU)
            scriviRigaCroma(bV, cy * pV.rowStride, pV.pixelStride, rigaV)
        }
    }

    private fun scriviRigaCroma(buf: ByteBuffer, inizio: Int, passo: Int, riga: ByteArray) {
        if (passo == 1) {
            buf.position(inizio)
            buf.put(riga)
        } else {
            for (x in riga.indices) buf.put(inizio + x * passo, riga[x])
        }
    }

    /** Passa al codificatore l'audio fino a [secondi]; con [finale] anche la fine del flusso. */
    private fun scriviAudioFinoA(secondi: Double, finale: Boolean) {
        val a = codAudio ?: return
        val pcm = audio ?: return
        if (audioEosInviato) return
        val obiettivo = if (finale) pcm.size else min(pcm.size, (secondi * LettoreAudio.FREQUENZA).toInt() * 4)
        while (audioScritto < obiettivo || (finale && !audioEosInviato)) {
            val i = a.dequeueInputBuffer(10_000)
            if (i < 0) {
                svuota(false)
                continue
            }
            val buf = a.getInputBuffer(i)!!
            buf.clear()
            val n = min(min(buf.capacity(), 16384) / 4 * 4, obiettivo - audioScritto)
            val pts = (audioScritto / 4).toLong() * 1_000_000L / LettoreAudio.FREQUENZA
            if (n <= 0) {
                a.queueInputBuffer(i, 0, 0, pts, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                audioEosInviato = true
                break
            }
            buf.put(pcm, audioScritto, n)
            a.queueInputBuffer(i, 0, n, pts, 0)
            audioScritto += n
        }
    }

    /** Raccoglie ciò che i codificatori hanno pronto; con [finale] aspetta la fine di entrambi. */
    private fun svuota(finale: Boolean) {
        var giri = 0
        while (true) {
            val pv = svuotaUno(video, true)
            val pa = codAudio?.let { svuotaUno(it, false) } ?: false
            if (!finale) {
                if (!pv && !pa) return
            } else {
                if (fineVideo && fineAudio) return
                if (!pv && !pa && ++giri > 1000) throw IllegalStateException("Il codificatore non termina")
            }
        }
    }

    /** Un'uscita di [cod]; vero se ha prodotto qualcosa. */
    private fun svuotaUno(cod: MediaCodec, eVideo: Boolean): Boolean {
        if (if (eVideo) fineVideo else fineAudio) return false
        val o = cod.dequeueOutputBuffer(info, 2_000)
        if (o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
            if (eVideo) tracciaVideo = muxer.addTrack(cod.outputFormat) else tracciaAudio = muxer.addTrack(cod.outputFormat)
            if (tracciaVideo >= 0 && (codAudio == null || tracciaAudio >= 0)) {
                muxer.start()
                avviato = true
                for ((v, dati, i) in inAttesa) muxer.writeSampleData(if (v) tracciaVideo else tracciaAudio, ByteBuffer.wrap(dati), i)
                inAttesa.clear()
            }
            return true
        }
        if (o < 0) return false
        val buf = cod.getOutputBuffer(o)!!
        if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) info.size = 0
        if (info.size > 0) {
            buf.position(info.offset)
            buf.limit(info.offset + info.size)
            if (avviato) {
                muxer.writeSampleData(if (eVideo) tracciaVideo else tracciaAudio, buf, info)
            } else {
                val copia = ByteArray(info.size)
                buf.get(copia)
                val i = MediaCodec.BufferInfo()
                i.set(0, info.size, info.presentationTimeUs, info.flags)
                inAttesa.add(Triple(eVideo, copia, i))
            }
        }
        cod.releaseOutputBuffer(o, false)
        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
            if (eVideo) fineVideo = true else fineAudio = true
        }
        return true
    }

    fun chiudi() {
        if (chiuso) return
        scriviAudioFinoA(0.0, true)
        var i: Int
        while (true) {
            i = video.dequeueInputBuffer(10_000)
            if (i >= 0) break
            svuota(false)
        }
        video.queueInputBuffer(i, 0, 0, fotogrammi * 1_000_000L / fps, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
        svuota(true)
        chiuso = true
        fermaCodificatori()
        if (!avviato) {
            muxer.release()
            File(percorso).delete()
            throw IllegalStateException("MP4 vuoto")
        }
        muxer.stop()
        muxer.release()
    }

    private fun fermaCodificatori() {
        for (c in listOfNotNull(video, codAudio)) {
            try {
                c.stop()
            } catch (_: Throwable) {
            }
            c.release()
        }
    }

    /** Interrompe e cancella il file a metà. */
    fun annulla() {
        if (!chiuso) {
            chiuso = true
            fermaCodificatori()
            if (avviato) {
                try {
                    muxer.stop()
                } catch (_: Throwable) {
                }
            }
        }
        try {
            muxer.release()
        } catch (_: Throwable) {
        }
        File(percorso).delete()
    }
}
