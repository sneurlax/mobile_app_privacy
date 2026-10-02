package com.cypherstack.mobile_app_privacy_example

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.registerExamplePlatformChannel()
        flutterEngine.registerPrivacyTestChannel(this)
    }
}
