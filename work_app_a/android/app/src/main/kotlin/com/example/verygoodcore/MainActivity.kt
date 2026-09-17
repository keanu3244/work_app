package com.example.verygoodcore.flutter_boilerplate

import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "work_app/push")
            .setMethodCallHandler { call, result ->
                if (call.method != "getDevicePushToken") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val app = FirebaseApp.initializeApp(this)
                    if (app == null) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    FirebaseMessaging.getInstance().token
                        .addOnSuccessListener { token -> result.success(token) }
                        .addOnFailureListener { result.success(null) }
                } catch (_: Exception) {
                    result.success(null)
                }
            }
    }
}
