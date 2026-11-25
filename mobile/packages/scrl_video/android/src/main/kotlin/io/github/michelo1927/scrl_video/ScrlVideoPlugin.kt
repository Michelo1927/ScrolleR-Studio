package io.github.michelo1927.scrl_video

import android.content.Context
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Plugin scrl_video (Android). Tutto il lavoro pesante gira in un thread a parte, uno solo:
 * le chiamate arrivano in ordine e i codificatori non vengono mai usati da due thread insieme.
 */
class ScrlVideoPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var canale: MethodChannel
    private lateinit var contesto: Context
    private var lavoro: ExecutorService? = null
    private val principale = Handler(Looper.getMainLooper())
    private val lettori = HashMap<Int, LettoreFotogrammi>()
    private val scrittori = HashMap<Int, ScrittoreMp4>()

    /** Audio della schermata Sottotitoli: si comanda dal thread principale (comandi brevi, mai in coda). */
    private val ascolti = HashMap<Int, Ascolto>()
    private var prossimoId = 1

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        contesto = binding.applicationContext
        lavoro = Executors.newSingleThreadExecutor()
        canale = MethodChannel(binding.binaryMessenger, "scrl_video")
        canale.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        canale.setMethodCallHandler(null)
        ascolti.values.forEach { it.ferma() }
        ascolti.clear()
        lavoro?.execute {
            lettori.values.forEach { it.chiudi() }
            scrittori.values.forEach { it.annulla() }
            lettori.clear()
            scrittori.clear()
        }
        lavoro?.shutdown()
        lavoro = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "disponibile") {
            result.success(true)
            return
        }
        if (call.method in COMANDI_ASCOLTO) {
            try {
                result.success(comandaAscolto(call))
            } catch (e: Throwable) {
                result.error("errore", e.message ?: e.javaClass.simpleName, null)
            }
            return
        }
        val esecutore = lavoro
        if (esecutore == null) {
            result.error("chiuso", "Plugin non attivo", null)
            return
        }
        esecutore.execute {
            try {
                val risposta = esegui(call)
                principale.post {
                    if (risposta === NON_IMPLEMENTATO) result.notImplemented() else result.success(risposta)
                }
            } catch (e: Throwable) {
                principale.post { result.error("errore", e.message ?: e.javaClass.simpleName, null) }
            }
        }
    }

    private fun esegui(call: MethodCall): Any? = when (call.method) {
        "info" -> info(call.argument<String>("sorgente")!!)
        "apriLettore" -> {
            val l = LettoreFotogrammi(
                contesto,
                call.argument<String>("sorgente")!!,
                call.argument<Int>("larghezza"),
                call.argument<Int>("altezza"),
                call.argument<Int>("latoMassimo"),
            )
            val id = prossimoId++
            lettori[id] = l
            mapOf("id" to id, "larghezza" to l.larghezzaUscita, "altezza" to l.altezzaUscita)
        }
        "fotogramma" -> lettori[call.argument<Int>("id")!!]!!.a(call.argument<Double>("t")!!)
        "chiudiLettore" -> {
            lettori.remove(call.argument<Int>("id")!!)?.chiudi()
            null
        }
        "leggiAudio" -> LettoreAudio.leggi(
            contesto,
            call.argument<String>("sorgente")!!,
            call.argument<Double>("inizio")!!,
            call.argument<Double>("fine")!!,
        )
        "apriAscolto" -> Ascolto.apri(contesto, call.argument<String>("sorgente")!!)?.let { a ->
            val id = prossimoId++
            val dati = a.byte()
            principale.post { ascolti[id] = a }
            mapOf("id" to id, "pcm" to dati, "frequenza" to Ascolto.FREQUENZA)
        }
        "apriScrittore" -> {
            val s = ScrittoreMp4(
                call.argument<String>("percorso")!!,
                call.argument<Int>("larghezza")!!,
                call.argument<Int>("altezza")!!,
                call.argument<Int>("fps")!!,
                call.argument<ByteArray>("audio"),
            )
            val id = prossimoId++
            scrittori[id] = s
            id
        }
        "aggiungiFotogramma" -> {
            scrittori[call.argument<Int>("id")!!]!!.aggiungi(call.argument<ByteArray>("rgba")!!)
            null
        }
        "chiudiScrittore" -> {
            val s = scrittori.remove(call.argument<Int>("id")!!)!!
            try {
                s.chiudi()
            } catch (e: Throwable) {
                s.annulla()
                throw e
            }
            null
        }
        "annullaScrittore" -> {
            scrittori.remove(call.argument<Int>("id")!!)?.annulla()
            null
        }
        else -> NON_IMPLEMENTATO
    }

    /** Comandi della riproduzione (thread principale): rispondono subito anche mentre si decodifica altro. */
    private fun comandaAscolto(call: MethodCall): Any? {
        val id = call.argument<Int>("id")!!
        if (call.method == "chiudiAscolto") {
            ascolti.remove(id)?.ferma()
            return null
        }
        val a = ascolti[id] ?: throw IllegalStateException("Audio chiuso")
        return when (call.method) {
            "suona" -> {
                a.suona(call.argument<Double>("t")!!, call.argument<Double>("velocita")!!)
                null
            }
            "ferma" -> a.ferma()
            "tempoAscolto" -> a.tempo()
            "velocitaAscolto" -> {
                a.cambiaVelocita(call.argument<Double>("velocita")!!)
                null
            }
            else -> null
        }
    }

    private fun info(sorgente: String): Map<String, Any> {
        val r = MediaMetadataRetriever()
        try {
            if (eUri(sorgente)) r.setDataSource(contesto, Uri.parse(sorgente)) else r.setDataSource(sorgente)
            var w = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
            var h = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
            val rot = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            if (rot % 180 != 0) w = h.also { h = w }
            val durata = (r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L) / 1000.0
            val audio = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO) == "yes"
            return mapOf("larghezza" to w, "altezza" to h, "durata" to durata, "fps" to fpsDi(sorgente), "audio" to audio)
        } finally {
            r.release()
        }
    }

    private fun fpsDi(sorgente: String): Double {
        val e = apriEstrattore(contesto, sorgente)
        try {
            val t = tracciaDi(e, "video/") ?: return 30.0
            val f = e.getTrackFormat(t)
            if (!f.containsKey(MediaFormat.KEY_FRAME_RATE)) return 30.0
            // Il valore può essere intero o decimale a seconda del contenitore
            return try {
                f.getInteger(MediaFormat.KEY_FRAME_RATE).toDouble()
            } catch (_: ClassCastException) {
                f.getFloat(MediaFormat.KEY_FRAME_RATE).toDouble()
            }
        } finally {
            e.release()
        }
    }

    companion object {
        private val NON_IMPLEMENTATO = Any()
        private val COMANDI_ASCOLTO = setOf("suona", "ferma", "tempoAscolto", "velocitaAscolto", "chiudiAscolto")

        fun eUri(sorgente: String) = sorgente.startsWith("content://") || sorgente.startsWith("file://")

        fun apriEstrattore(contesto: Context, sorgente: String): MediaExtractor {
            val e = MediaExtractor()
            try {
                if (eUri(sorgente)) e.setDataSource(contesto, Uri.parse(sorgente), null) else e.setDataSource(sorgente)
            } catch (t: Throwable) {
                e.release()
                throw t
            }
            return e
        }

        /** Prima traccia il cui tipo inizia con [prefisso] ("video/" o "audio/"). */
        fun tracciaDi(e: MediaExtractor, prefisso: String): Int? {
            for (i in 0 until e.trackCount) {
                if (e.getTrackFormat(i).getString(MediaFormat.KEY_MIME)?.startsWith(prefisso) == true) return i
            }
            return null
        }
    }
}
