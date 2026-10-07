package com.example.app_pdf

import android.app.ActivityManager
import android.os.Build
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
