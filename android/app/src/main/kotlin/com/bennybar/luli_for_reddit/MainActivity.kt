package com.bennybar.luli_for_reddit

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build
import android.content.ClipboardManager
import android.content.Context
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val clipboardReader = Executors.newSingleThreadExecutor()
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lily/media_clipboard")
            .setMethodCallHandler { call, result ->
                if (call.method != "readImage") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    val clip = clipboard.primaryClip
                    val uri = if (clip != null && clip.itemCount > 0) clip.getItemAt(0).uri else null
                    if (uri == null || uri.scheme != "content") {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    val mime = contentResolver.getType(uri)
                    if (mime == null || !mime.startsWith("image/")) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    clipboardReader.execute {
                        try {
                            val bytes = contentResolver.openInputStream(uri)?.use { input ->
                                val output = ByteArrayOutputStream()
                                val buffer = ByteArray(8192)
                                var total = 0
                                while (true) {
                                    val count = input.read(buffer)
                                    if (count < 0) break
                                    total += count
                                    if (total > 20 * 1024 * 1024) throw IllegalArgumentException("Image too large")
                                    output.write(buffer, 0, count)
                                }
                                output.toByteArray()
                            }
                            runOnUiThread { result.success(bytes?.let { mapOf("bytes" to it, "mimeType" to mime) }) }
                        } catch (_: SecurityException) {
                            runOnUiThread { result.error("clipboard_denied", "Copy the image again or use Attach image.", null) }
                        } catch (_: IllegalArgumentException) {
                            runOnUiThread { result.error("clipboard_too_large", "Choose an image smaller than 20 MB.", null) }
                        } catch (_: Exception) {
                            runOnUiThread { result.error("clipboard_read_failed", "Could not read that image. Use Attach image instead.", null) }
                        }
                    }
                } catch (_: Exception) {
                    result.error("clipboard_read_failed", "Copy the image again or use Attach image.", null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lily/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "supportedAbis") {
                    result.success(Build.SUPPORTED_ABIS.toList())
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        clipboardReader.shutdown()
        super.onDestroy()
    }
}
