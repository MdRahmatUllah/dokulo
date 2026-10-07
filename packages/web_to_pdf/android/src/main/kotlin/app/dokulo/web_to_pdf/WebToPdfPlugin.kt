package app.dokulo.web_to_pdf

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.pdf.PdfRenderer
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.print.PdfPrinter
import android.print.PrintAttributes
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Web page or HTML to a paginated PDF (DK-0399): an off-screen WebView printed to a file. */
class WebToPdfPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "dokulo/web_to_pdf")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "print") {
            result.notImplemented()
            return
        }
        val html: String? = call.argument("html")
        val url: String? = call.argument("url")
        val baseUrl: String? = call.argument("baseUrl")
        val out = File(call.argument<String>("output")!!)
        val size = if (call.argument<String>("pageSize") == "letter") {
            PrintAttributes.MediaSize.NA_LETTER
        } else {
            PrintAttributes.MediaSize.ISO_A4
        }
        // Margins in mils: 500 = 12.7 mm, the "Default" of §21.9.
        val margins = if (call.argument<Boolean>("margins") == false) {
            PrintAttributes.Margins.NO_MARGINS
        } else {
            PrintAttributes.Margins(500, 500, 500, 500)
        }
        val backgrounds = call.argument<Boolean>("backgrounds") ?: true
        val timeoutMs = (call.argument<Int>("timeoutMs") ?: 30000).toLong()
        val attributes = PrintAttributes.Builder()
            .setMediaSize(size)
            .setResolution(PrintAttributes.Resolution("pdf", "pdf", 300, 300))
            .setMinMargins(margins)
            .build()
        main.post { load(html, url, baseUrl, out, attributes, backgrounds, timeoutMs, result) }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun load(
        html: String?, url: String?, baseUrl: String?, out: File, attributes: PrintAttributes,
        backgrounds: Boolean, timeoutMs: Long, result: MethodChannel.Result,
    ) {
        val web = WebView(context)
        web.settings.javaScriptEnabled = true // pages need it to render; no bridge is exposed
        web.settings.allowFileAccess = html != null // an HTML file's own images and styles
        var done = false
        fun finish(code: String?, message: String?, pages: Int = 0) {
            if (done) return
            done = true
            main.removeCallbacksAndMessages(web)
            web.destroy()
            if (code == null) result.success(pages) else result.error(code, message, null)
        }
        main.postAtTime({ finish("timeout", "The page took longer than ${timeoutMs / 1000} s") }, web,
            android.os.SystemClock.uptimeMillis() + timeoutMs)
        web.webViewClient = object : WebViewClient() {
            override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                if (request.isForMainFrame) finish("load_failed", error.description.toString())
            }

            override fun onPageFinished(view: WebView, loaded: String) {
                if (done) return
                // Print backgrounds (colours, images) as on screen when asked; the print default leaves them out.
                if (backgrounds) {
                    view.evaluateJavascript(
                        "(function(){var s=document.createElement('style');" +
                            "s.textContent='*{-webkit-print-color-adjust:exact !important;print-color-adjust:exact !important}';" +
                            "document.head.appendChild(s)})()", null)
                }
                // Let late layout settle, then print once.
                main.postAtTime({
                    if (done) return@postAtTime
                    PdfPrinter.print(view.createPrintDocumentAdapter("Dokulo"), attributes, out) { error ->
                        if (error != null) finish("failed", error) else finish(null, null, pageCount(out))
                    }
                }, web, android.os.SystemClock.uptimeMillis() + 300)
            }
        }
        if (html != null) {
            web.loadDataWithBaseURL(baseUrl, html, "text/html", "UTF-8", null)
        } else {
            web.loadUrl(url!!)
        }
    }

    private fun pageCount(file: File): Int =
        ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
            PdfRenderer(fd).use { it.pageCount }
        }
}
