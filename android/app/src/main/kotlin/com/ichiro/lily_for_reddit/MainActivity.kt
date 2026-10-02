package com.ichiro.lily_for_reddit

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build
import android.content.ClipboardManager
import android.content.Context
import android.net.Uri
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val clipboardReader = Executors.newSingleThreadExecutor()
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lily/media_clipboard")
            .setMethodCallHandler { call, result ->
                if (call.method != "readImage" && call.method != "readKeyboardImage") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val uri = if (call.method == "readKeyboardImage") {
                        call.argument<String>("uri")?.let { Uri.parse(it) }
                    } else {
                        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        val clip = clipboard.primaryClip
                        if (clip != null && clip.itemCount > 0) clip.getItemAt(0).uri else null
                    }
                    if (uri == null || uri.scheme != "content") {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    val mime = contentResolver.getType(uri) ?: call.argument<String>("mimeType")
                    if (mime !in setOf("image/png", "image/jpeg", "image/gif", "image/webp")) {
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
