package com.example.verygoodcore.flutter_boilerplate

import android.content.Intent
import android.net.Uri
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "work_app/system")
            .setMethodCallHandler { call, result ->
                if (call.method != "openUrl") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val url = call.argument<String>("url")
                if (url.isNullOrBlank()) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                    result.success(true)
                } catch (_: Exception) {
                    result.success(false)
                }
            }
    }
}
