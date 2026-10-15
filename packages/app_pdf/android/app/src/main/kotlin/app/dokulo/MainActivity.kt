package app.dokulo

import android.Manifest
import android.app.ActivityManager
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.os.StatFs
import android.print.PageRange
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintDocumentInfo
import android.print.PrintManager
import android.provider.OpenableColumns
import android.provider.Settings
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

// A FragmentActivity: local_auth's biometric prompt needs one (DK-0282).
class MainActivity : FlutterFragmentActivity() {
    private var pendingCamera: MethodChannel.Result? = null
    private var pendingNotifications: MethodChannel.Result? = null
    private val prefs by lazy { getSharedPreferences("dokulo_permissions", MODE_PRIVATE) }

    // Files shared to Dokulo or opened with it (DK-0235; lib/providers/incoming_providers.dart):
    // copied into the cache off the main thread, then held until Dart takes them.
    private val incoming = mutableListOf<Map<String, Any>>()
    private var incomingChannel: MethodChannel? = null
    private val copier = Executors.newSingleThreadExecutor()

    override fun onCreate(savedInstanceState: Bundle?) {
        // Before super: Flutter would read a content:// VIEW as a route. A
        // restore or a launch from recents brings the old intent back, which
        // was taken the first time.
        val fresh = savedInstanceState == null &&
            (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) == 0
        if (isIncoming(intent)) {
            if (fresh) receive(intent)
            intent = Intent(Intent.ACTION_MAIN)
        }
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        if (!isIncoming(intent)) {
            super.onNewIntent(intent)
            return
        }
        receive(intent)
        super.onNewIntent(Intent(Intent.ACTION_MAIN))
    }

    private fun isIncoming(intent: Intent?): Boolean = when (intent?.action) {
        Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE -> true
        Intent.ACTION_VIEW -> intent.data?.scheme.let { it == "content" || it == "file" }
        else -> false
    }

    @Suppress("DEPRECATION") // the typed getParcelable* need API 33; minSdk is 26
    private fun receive(intent: Intent) {
        val uris = when (intent.action) {
            Intent.ACTION_VIEW -> listOfNotNull(intent.data)
            Intent.ACTION_SEND -> listOfNotNull(intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM))
            else -> intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM).orEmpty()
        }
        if (uris.isEmpty()) return
        val action = if (intent.action == Intent.ACTION_VIEW) "view" else "send"
        // The grant to read the URIs lasts as long as this activity.
        copier.execute {
            val dir = File(cacheDir, "incoming/${System.nanoTime()}").apply { mkdirs() }
            val paths = uris.mapIndexedNotNull { i, uri -> copyIn(uri, dir, i) }
            if (paths.isEmpty()) return@execute
            runOnUiThread {
                incoming.add(mapOf("action" to action, "paths" to paths))
                incomingChannel?.invokeMethod("available", null)
            }
        }
    }

    /** One shared file into [dir] under its own name; null if it can't be read. */
    private fun copyIn(uri: Uri, dir: File, index: Int): String? = try {
        val mime = contentResolver.getType(uri)
        var name = displayName(uri)?.replace('/', '_')?.takeIf { it.isNotBlank() }
            ?: "Shared ${index + 1}"
        val ext = when {
            mime == "application/pdf" -> "pdf"
            mime?.startsWith("image/") == true -> mime.removePrefix("image/").replace("jpeg", "jpg")
            else -> null
        }
        if (ext != null && !name.contains('.')) name += ".$ext"
        val out = File(File(dir, "$index").apply { mkdirs() }, name)
        contentResolver.openInputStream(uri)!!.use { input ->
            out.outputStream().use { input.copyTo(it) }
        }
        out.path
    } catch (e: Exception) {
        null
    }

    private fun displayName(uri: Uri): String? =
        if (uri.scheme == "file") uri.lastPathSegment
        else contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { c -> if (c.moveToFirst()) c.getString(0) else null }

    // granted, notAsked (the system never asked: S1 shows the pre-prompt) or
    // denied. Android can't tell "never asked" from "denied" by itself, so we
    // remember that we asked.
    private fun cameraStatus(): String = when {
        ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED -> "granted"
        !prefs.getBoolean("camera_asked", false) -> "notAsked"
        else -> "denied"
    }

    // Notices for long jobs (DK-0378): Android 13+ asks for
    // POST_NOTIFICATIONS; older ones only say whether notices are on.
    private fun notificationStatus(): String = when {
        Build.VERSION.SDK_INT < 33 ->
            if (NotificationManagerCompat.from(this).areNotificationsEnabled()) "granted"
            else "denied"
        ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED -> "granted"
        !prefs.getBoolean("notifications_asked", false) -> "notAsked"
        else -> "denied"
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == CAMERA_REQUEST) {
            pendingCamera?.success(cameraStatus())
            pendingCamera = null
        }
        if (requestCode == NOTIFICATIONS_REQUEST) {
            pendingNotifications?.success(notificationStatus())
            pendingNotifications = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The camera permission (DK-0342; lib/providers/camera_permission.dart).
        // The app asks once; after a "no" only Settings can change it.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dokulo/camera")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(cameraStatus())
                    "request" -> {
                        if (cameraStatus() != "notAsked") {
                            result.success(cameraStatus())
                        } else {
                            pendingCamera?.success(cameraStatus())
                            pendingCamera = result
                            prefs.edit().putBoolean("camera_asked", true).apply()
                            ActivityCompat.requestPermissions(
                                this, arrayOf(Manifest.permission.CAMERA), CAMERA_REQUEST,
                            )
                        }
                    }
                    "openSettings" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.fromParts("package", packageName, null),
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        // Notices for long jobs (DK-0378; lib/providers/notification_permission.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dokulo/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(notificationStatus())
                    "request" -> {
                        if (notificationStatus() != "notAsked") {
                            result.success(notificationStatus())
                        } else {
                            pendingNotifications?.success(notificationStatus())
                            pendingNotifications = result
                            prefs.edit().putBoolean("notifications_asked", true).apply()
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                NOTIFICATIONS_REQUEST,
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        // "Send report by email" (DK-1080; lib/providers/mail_providers.dart):
        // the draft goes to the user's mail app; nothing is sent by the app.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dokulo/mail")
            .setMethodCallHandler { call, result ->
                if (call.method != "compose") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val intent = Intent(Intent.ACTION_SENDTO, Uri.parse(call.arguments as String))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                try {
                    startActivity(intent)
                    result.success(true)
                } catch (e: android.content.ActivityNotFoundException) {
                    result.success(false)
                }
            }
        // A web link in a PDF, after V1 asked (DK-1088; lib/providers/link_providers.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dokulo/links")
            .setMethodCallHandler { call, result ->
                val url = call.arguments as? String
                if (call.method != "open" || url == null) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    startActivity(
                        Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    result.success(true)
                } catch (e: android.content.ActivityNotFoundException) {
                    result.success(false)
                }
            }
        // Print (DK-0295; lib/providers/print_providers.dart): the system's
        // print dialog for one PDF.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dokulo/print")
            .setMethodCallHandler { call, result ->
                val path = call.argument<String>("path")
                if (call.method != "pdf" || path == null) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val name = call.argument<String>("name") ?: File(path).name
                (getSystemService(PRINT_SERVICE) as PrintManager)
                    .print(name, PdfPrintAdapter(File(path), name), null)
                result.success(true)
            }
        // Shared and "Open with" files (DK-0235): Dart takes the batches
        // copied so far; "available" says another one is ready.
        incomingChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dokulo/incoming")
            .apply {
                setMethodCallHandler { call, result ->
                    if (call.method != "take") {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                    result.success(incoming.toList())
                    incoming.clear()
                }
            }
        // The privacy cover (DK-0234; lib/providers/privacy_providers.dart):
        // FLAG_SECURE blanks the recents card and blocks screenshots, only
        // while locked content is open or Hide previews is on.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dokulo/privacy")
            .setMethodCallHandler { call, result ->
                if (call.method != "setSecure") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (call.arguments == true) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
                result.success(null)
            }
        // HEIC/HEIF photos as JPEGs for the image tools (DK-1081;
        // lib/providers/image_providers.dart): ImageDecoder (Android 9+)
        // applies the EXIF orientation; off the main thread, a big photo
        // takes a moment. False on Android 8 or when it doesn't decode.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dokulo/images")
            .setMethodCallHandler { call, result ->
                val from = call.argument<String>("from")
                val to = call.argument<String>("to")
                if (call.method != "heicToJpeg" || from == null || to == null) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                Thread {
                    val ok = try {
                        val bitmap = ImageDecoder.decodeBitmap(
                            ImageDecoder.createSource(File(from)),
                        )
                        FileOutputStream(to).use {
                            bitmap.compress(Bitmap.CompressFormat.JPEG, 92, it)
                        }
                    } catch (e: Exception) {
                        false
                    }
                    runOnUiThread { result.success(ok) }
                }.start()
            }
        // What the phone can do (DK-0013; ai_core's DeviceCapabilities reads this map).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dokulo/device")
            .setMethodCallHandler { call, result ->
                if (call.method != "capabilities") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val memory = ActivityManager.MemoryInfo()
                (getSystemService(ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(memory)
                // The volume the app's files, and so the models, live on.
                val storage = StatFs(filesDir.path)
                result.success(
                    mapOf(
                        "totalRam" to memory.totalMem,
                        "availableRam" to memory.availMem,
                        "freeStorage" to storage.availableBytes,
                        "totalStorage" to storage.totalBytes,
                        "abis" to Build.SUPPORTED_ABIS.toList(),
                        "os" to "android",
                        "osVersion" to Build.VERSION.RELEASE,
                    )
                )
            }
    }
}

private const val CAMERA_REQUEST = 4201
private const val NOTIFICATIONS_REQUEST = 4202

/** Hands a PDF file to the print framework as it is. */
private class PdfPrintAdapter(private val file: File, private val name: String) :
    PrintDocumentAdapter() {
    override fun onLayout(
        oldAttributes: PrintAttributes?,
        newAttributes: PrintAttributes,
        cancellationSignal: CancellationSignal?,
        callback: LayoutResultCallback,
        extras: Bundle?,
    ) {
        if (cancellationSignal?.isCanceled == true) {
            callback.onLayoutCancelled()
            return
        }
        callback.onLayoutFinished(
            PrintDocumentInfo.Builder(name)
                .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
                .build(),
            true,
        )
    }

    override fun onWrite(
        pages: Array<out PageRange>,
        destination: ParcelFileDescriptor,
        cancellationSignal: CancellationSignal?,
        callback: WriteResultCallback,
    ) {
        try {
            file.inputStream().use { input ->
                FileOutputStream(destination.fileDescriptor).use { input.copyTo(it) }
            }
            callback.onWriteFinished(arrayOf(PageRange.ALL_PAGES))
        } catch (e: Exception) {
            callback.onWriteFailed(e.message)
        }
    }
}
