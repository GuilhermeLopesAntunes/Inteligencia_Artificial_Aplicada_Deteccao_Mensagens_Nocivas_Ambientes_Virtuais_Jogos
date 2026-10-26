package com.example.frontend

import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    companion object {
        @Volatile
        var isInForeground: Boolean = false
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startMonitorService()
    }

    override fun onResume() {
        super.onResume()
        isInForeground = true
        startMonitorService()
    }

    override fun onPause() {
        isInForeground = false
        super.onPause()
    }

    override fun onDestroy() {
        isInForeground = false
        super.onDestroy()
    }

    private fun startMonitorService() {
        try {
            val serviceIntent = Intent(this, ArtemisMonitorService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
        } catch (_: Exception) {
        }
    }
}
