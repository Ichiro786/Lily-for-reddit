package com.bennybar.luli_for_reddit

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lily/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "supportedAbis") {
                    result.success(Build.SUPPORTED_ABIS.toList())
                } else {
                    result.notImplemented()
                }
            }
    }
}
