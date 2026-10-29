package com.example.jariyo_frontend

import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var toast: Toast? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "channel")

        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "toast" -> {
                    toast?.cancel()
                    toast = Toast.makeText(context, call.arguments.toString(), Toast.LENGTH_SHORT)
                    toast?.show()
                    result.success(null)
                }
            }
        }
    }
}
