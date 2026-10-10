package app.dokulo

import android.Manifest
import android.app.ActivityManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.StatFs
import android.provider.Settings
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// A FragmentActivity: local_auth's biometric prompt needs one (DK-0282).
class MainActivity : FlutterFragmentActivity() {
    private var pendingCamera: MethodChannel.Result? = null
    private var pendingNotifications: MethodChannel.Result? = null
    private val prefs by lazy { getSharedPreferences("dokulo_permissions", MODE_PRIVATE) }

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
