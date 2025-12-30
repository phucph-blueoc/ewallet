package com.ewallet.ewallet_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register anti-tampering plugin
        flutterEngine.plugins.add(AntiTamperingPlugin())
    }
}
