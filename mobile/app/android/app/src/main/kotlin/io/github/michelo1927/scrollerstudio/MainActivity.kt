package io.github.michelo1927.scrollerstudio

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

/**
 * Attività principale. Oltre a ospitare Flutter, riceve i file che arrivano da altre app (piano §6, Fase 9):
 * «Apri con ScrolleR Studio» (`.scrlproj`, `.zip`) e «Condividi con ScrolleR Studio» (foto, video, zip).
 *
 * Un `content://` di un'altra app vale solo finché l'intent è vivo e non si legge da Dart: i file si copiano a blocchi
 * (mai in memoria) in `cache/ricevuti/` e a Dart si consegna l'elenco delle copie, una volta sola. Dart le toglie dopo
 * l'uso; quelle rimaste si tolgono al prossimo avvio.
 */
class MainActivity : FlutterActivity() {
    private val esecutore = Executors.newSingleThreadExecutor()
    private val lock = Any()
    private val inAttesa = mutableListOf<Map<String, String?>>()
    private var canale: MethodChannel? = null
    private var dartPronto = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        esecutore.execute { pulisciVecchi() }
        // Con lo stato salvato l'attività si ricrea con l'intent di prima: i file sono già stati presi
        if (savedInstanceState == null) acquisisci(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        acquisisci(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val c = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOME_CANALE)
        c.setMethodCallHandler { call, result ->
            if (call.method == "iniziali") {
                val l: List<Map<String, String?>>
                synchronized(lock) {
                    dartPronto = true
                    l = inAttesa.toList()
                    inAttesa.clear()
                }
                result.success(l)
            } else {
                result.notImplemented()
            }
        }
        canale = c
    }

    override fun onDestroy() {
        esecutore.shutdown()
        super.onDestroy()
    }

    /** Elenco degli URI che l'intent porta (VIEW, SEND, SEND_MULTIPLE). */
    private fun uriDi(intent: Intent?): List<Uri> {
        if (intent == null) return emptyList()
        val out = LinkedHashSet<Uri>()
        when (intent.action) {
            Intent.ACTION_VIEW -> intent.data?.let { out.add(it) }
            Intent.ACTION_SEND -> {
                val u = if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION") intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                }
                u?.let { out.add(it) }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val l = if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION") intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                }
                l?.let { out.addAll(it) }
            }
            else -> return emptyList()
        }
        // Alcune app mettono gli URI solo nella ClipData
        if (out.isEmpty()) {
            val clip = intent.clipData
            if (clip != null) for (i in 0 until clip.itemCount) clip.getItemAt(i).uri?.let { out.add(it) }
        }
        return out.toList()
    }

    private fun acquisisci(intent: Intent?) {
        val uris = uriDi(intent)
        if (uris.isEmpty()) return
        // L'intent è consumato: una rotazione o un ritorno all'app non importano di nuovo
        intent?.action = Intent.ACTION_MAIN
        esecutore.execute {
            val copie = uris.mapNotNull { copia(it) }
            if (copie.isEmpty()) return@execute
            var subito = false
            synchronized(lock) {
                if (dartPronto) subito = true else inAttesa.addAll(copie)
            }
            if (subito) runOnUiThread { canale?.invokeMethod("nuovi", copie) }
        }
    }

    private fun nomeDi(uri: Uri): String {
        var nome: String? = null
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
                if (it.moveToFirst()) nome = it.getString(0)
            }
        } catch (_: Exception) {
            // L'app che ha mandato il file non dà il nome: si ripiega sull'URI
        }
        val n = nome ?: uri.lastPathSegment ?: "file"
        return n.substringAfterLast('/').substringAfterLast('\\').ifBlank { "file" }
    }

    /** Copia il file dietro [uri] in `cache/ricevuti/<id>/<nome>`; null se non si riesce a leggerlo. */
    private fun copia(uri: Uri): Map<String, String?>? {
        return try {
            val nome = nomeDi(uri)
            val dir = File(File(cacheDir, "ricevuti"), UUID.randomUUID().toString())
            dir.mkdirs()
            val dest = File(dir, nome)
            val input = contentResolver.openInputStream(uri) ?: return null
            input.use { i -> dest.outputStream().use { o -> i.copyTo(o, 64 * 1024) } }
            mapOf("percorso" to dest.absolutePath, "nome" to nome, "mime" to contentResolver.getType(uri))
        } catch (_: Exception) {
            null
        }
    }

    /** Copie di avvii precedenti mai ritirate da Dart (app chiusa a metà): più vecchie di un giorno si tolgono. */
    private fun pulisciVecchi() {
        val base = File(cacheDir, "ricevuti")
        val limite = System.currentTimeMillis() - 24L * 60 * 60 * 1000
        base.listFiles()?.forEach { if (it.lastModified() < limite) it.deleteRecursively() }
    }

    companion object {
        const val NOME_CANALE = "io.github.michelo1927.scrollerstudio/ricevuti"
    }
}
