package io.github.michelo1927.scrl_video

import android.content.Context
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Lettura in sequenza dei fotogrammi (come `FrameReader` del desktop): [a] va avanti decodificando
 * e torna indietro (o salta lontano) con una ricerca. Restituisce l'ultimo fotogramma con tempo ≤ t,
 * in RGBA, già ruotato come appare e alla misura chiesta.
 */
class LettoreFotogrammi(
    contesto: Context,
    sorgente: String,
    larghezza: Int?,
    altezza: Int?,
    latoMassimo: Int?,
) {
    private val estrattore: MediaExtractor = ScrlVideoPlugin.apriEstrattore(contesto, sorgente)
    private val decodificatore: MediaCodec
    private val rotazione: Int
    private val inizioUs: Long
    private val eps: Double
    private val codW: Int
    private val codH: Int
    val larghezzaUscita: Int
    val altezzaUscita: Int

    private class Pronto(val indice: Int, val t: Double)

    private var attuale: Pronto? = null
    private var attualeT: Double? = null
    private var attualeRgba: ByteArray? = null
    private var successivo: Pronto? = null
    private var fineIngresso = false
    private var fineUscita = false
    private var avviato = false
    private var formatoUscita: MediaFormat? = null
    private val info = MediaCodec.BufferInfo()

    init {
        try {
            val traccia = ScrlVideoPlugin.tracciaDi(estrattore, "video/") ?: throw IllegalArgumentException("Nessuna traccia video")
            estrattore.selectTrack(traccia)
            val formato = estrattore.getTrackFormat(traccia)
            codW = formato.getInteger(MediaFormat.KEY_WIDTH)
            codH = formato.getInteger(MediaFormat.KEY_HEIGHT)
            rotazione = leggiRotazione(contesto, sorgente, formato)
            inizioUs = max(0L, estrattore.sampleTime)
            val fps = if (formato.containsKey(MediaFormat.KEY_FRAME_RATE)) {
                try {
                    formato.getInteger(MediaFormat.KEY_FRAME_RATE).toDouble()
                } catch (_: ClassCastException) {
                    formato.getFloat(MediaFormat.KEY_FRAME_RATE).toDouble()
                }
            } else 30.0
            eps = 0.5 / max(1.0, fps)
            val (vistoW, vistoH) = if (rotazione % 180 != 0) codH to codW else codW to codH
            if (larghezza != null && altezza != null) {
                larghezzaUscita = larghezza
                altezzaUscita = altezza
            } else {
                val k = if (latoMassimo != null) min(1.0, latoMassimo.toDouble() / max(vistoW, vistoH)) else 1.0
                larghezzaUscita = max(1, (vistoW * k).roundToInt())
                altezzaUscita = max(1, (vistoH * k).roundToInt())
            }
            formato.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible)
            val mime = formato.getString(MediaFormat.KEY_MIME)!!
            decodificatore = MediaCodec.createDecoderByType(mime)
            decodificatore.configure(formato, null, null, 0)
            decodificatore.start()
        } catch (t: Throwable) {
            estrattore.release()
            throw t
        }
    }

    private fun leggiRotazione(contesto: Context, sorgente: String, formato: MediaFormat): Int {
        if (formato.containsKey(MediaFormat.KEY_ROTATION)) return ((formato.getInteger(MediaFormat.KEY_ROTATION) % 360) + 360) % 360
        val r = MediaMetadataRetriever()
        return try {
            if (ScrlVideoPlugin.eUri(sorgente)) r.setDataSource(contesto, Uri.parse(sorgente)) else r.setDataSource(sorgente)
            ((r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0) % 360 + 360) % 360
        } catch (_: Throwable) {
            0
        } finally {
            r.release()
        }
    }

    fun a(t: Double): ByteArray? {
        val cur = attualeT
        if (!avviato || cur == null || t < cur - eps || t > cur + 2.0) cerca(t)
        while (true) {
            tira()
            val s = successivo ?: break
            if (s.t > t + eps) break
            sostituisciAttuale(s)
            successivo = null
        }
        if (attualeT == null) {
            // Prima del primo fotogramma (o ricerca finita poco dopo): si usa il primo disponibile
            val s = successivo
            if (s != null) {
                sostituisciAttuale(s)
                successivo = null
            }
        }
        val p = attuale
        if (attualeRgba == null && p != null) {
            attualeRgba = converti(p.indice)
            decodificatore.releaseOutputBuffer(p.indice, false)
            attuale = null
        }
        return attualeRgba
    }

    private fun sostituisciAttuale(nuovo: Pronto) {
        attuale?.let { decodificatore.releaseOutputBuffer(it.indice, false) }
        attuale = nuovo
        attualeT = nuovo.t
        attualeRgba = null
    }

    private fun cerca(t: Double) {
        attuale?.let { decodificatore.releaseOutputBuffer(it.indice, false) }
        successivo?.let { decodificatore.releaseOutputBuffer(it.indice, false) }
        attuale = null
        successivo = null
        attualeT = null
        attualeRgba = null
        if (avviato) decodificatore.flush()
        avviato = true
        estrattore.seekTo(inizioUs + (max(0.0, t) * 1_000_000).toLong(), MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
        fineIngresso = false
        fineUscita = false
    }

    /** Porta in [successivo] il prossimo fotogramma decodificato (se non c'è già e il video non è finito). */
    private fun tira() {
        var tentativi = 0
        while (successivo == null && !fineUscita) {
            if (!fineIngresso) {
                val i = decodificatore.dequeueInputBuffer(5_000)
                if (i >= 0) {
                    val buf = decodificatore.getInputBuffer(i)!!
                    val n = estrattore.readSampleData(buf, 0)
                    if (n < 0) {
                        decodificatore.queueInputBuffer(i, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        fineIngresso = true
                    } else {
                        decodificatore.queueInputBuffer(i, 0, n, estrattore.sampleTime, 0)
                        estrattore.advance()
                    }
                }
            }
            val o = decodificatore.dequeueOutputBuffer(info, 5_000)
            when {
                o >= 0 -> {
                    val eos = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                    if (info.size > 0 || !eos) {
                        successivo = Pronto(o, (info.presentationTimeUs - inizioUs) / 1_000_000.0)
                    } else {
                        decodificatore.releaseOutputBuffer(o, false)
                    }
                    if (eos) fineUscita = true
                    tentativi = 0
                }
                o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> formatoUscita = decodificatore.outputFormat
                else -> if (++tentativi > 400) fineUscita = true // Decodificatore fermo: si considera finito
            }
        }
    }

    /** Fotogramma YUV → RGBA alla misura d'uscita, con la rotazione del video (campionamento al più vicino). */
    private fun converti(indice: Int): ByteArray {
        val img = decodificatore.getOutputImage(indice) ?: throw IllegalStateException("Fotogramma non leggibile")
        try {
            val crop = img.cropRect
            val cw = crop.width()
            val ch = crop.height()
            val pY = img.planes[0]
            val pU = img.planes[1]
            val pV = img.planes[2]
            val y = ByteArray(pY.buffer.remaining()).also { pY.buffer.get(it) }
            val u = ByteArray(pU.buffer.remaining()).also { pU.buffer.get(it) }
            val v = ByteArray(pV.buffer.remaining()).also { pV.buffer.get(it) }
            val ow = larghezzaUscita
            val oh = altezzaUscita
            val vistoW = if (rotazione % 180 != 0) ch else cw
            val vistoH = if (rotazione % 180 != 0) cw else ch
            val sx = IntArray(ow) { min(vistoW - 1, ((it + 0.5) * vistoW / ow).toInt()) }
            val sy = IntArray(oh) { min(vistoH - 1, ((it + 0.5) * vistoH / oh).toInt()) }
            val (kr, kgU, kgV, kb) = coefficienti()
            val pieno = gammaPiena()
            val out = ByteArray(ow * oh * 4)
            var o = 0
            for (oy in 0 until oh) {
                val dy = sy[oy]
                for (ox in 0 until ow) {
                    val dx = sx[ox]
                    // Dal punto come appare al punto codificato
                    val cx: Int
                    val cy: Int
                    when (rotazione) {
                        90 -> { cx = dy; cy = ch - 1 - dx }
                        180 -> { cx = cw - 1 - dx; cy = ch - 1 - dy }
                        270 -> { cx = cw - 1 - dy; cy = dx }
                        else -> { cx = dx; cy = dy }
                    }
                    val px = crop.left + cx
                    val py = crop.top + cy
                    var yy = (y[py * pY.rowStride + px * pY.pixelStride].toInt() and 0xFF).toFloat()
                    val ci = (py / 2) * pU.rowStride + (px / 2) * pU.pixelStride
                    val cj = (py / 2) * pV.rowStride + (px / 2) * pV.pixelStride
                    var uu = (u[ci].toInt() and 0xFF) - 128f
                    var vv = (v[cj].toInt() and 0xFF) - 128f
                    if (!pieno) {
                        yy = (yy - 16f) * (255f / 219f)
                        uu *= 255f / 224f
                        vv *= 255f / 224f
                    }
                    out[o] = limita(yy + kr * vv)
                    out[o + 1] = limita(yy - kgU * uu - kgV * vv)
                    out[o + 2] = limita(yy + kb * uu)
                    out[o + 3] = 0xFF.toByte()
                    o += 4
                }
            }
            return out
        } finally {
            img.close()
        }
    }

    private data class Coeff(val r: Float, val gU: Float, val gV: Float, val b: Float)

    /** Coefficienti YUV → RGB: BT.601 o BT.709 secondo il video (HD senza indicazioni: 709). */
    private fun coefficienti(): Coeff {
        val f = formatoUscita
        val standard = if (f != null && f.containsKey(MediaFormat.KEY_COLOR_STANDARD)) f.getInteger(MediaFormat.KEY_COLOR_STANDARD) else 0
        val bt709 = when (standard) {
            MediaFormat.COLOR_STANDARD_BT709 -> true
            MediaFormat.COLOR_STANDARD_BT601_NTSC, MediaFormat.COLOR_STANDARD_BT601_PAL -> false
            else -> max(codW, codH) >= 1280
        }
        return if (bt709) Coeff(1.5748f, 0.1873f, 0.4681f, 1.8556f) else Coeff(1.402f, 0.3441f, 0.7141f, 1.772f)
    }

    private fun gammaPiena(): Boolean {
        val f = formatoUscita ?: return false
        return f.containsKey(MediaFormat.KEY_COLOR_RANGE) && f.getInteger(MediaFormat.KEY_COLOR_RANGE) == MediaFormat.COLOR_RANGE_FULL
    }

    private fun limita(x: Float): Byte {
        val i = (x + 0.5f).toInt()
        return (if (i < 0) 0 else if (i > 255) 255 else i).toByte()
    }

    fun chiudi() {
        try {
            decodificatore.stop()
        } catch (_: Throwable) {
        }
        decodificatore.release()
        estrattore.release()
    }
}
