package com.theforis.file_manager

import android.os.Environment
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Total and free bytes of a volume, for the storage overview on the home screen.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "burrow/storage").setMethodCallHandler { call, result ->
            if (call.method != "space") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                val path = call.argument<String>("path") ?: Environment.getExternalStorageDirectory().path
                val stat = StatFs(path)
                result.success(mapOf("total" to stat.totalBytes, "free" to stat.availableBytes))
            } catch (e: Exception) {
                result.error("unavailable", e.message, null)
            }
        }
    }
}
