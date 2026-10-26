package com.example.frontend

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.BitmapFactory
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.roundToInt

class ArtemisMonitorService : Service() {

    companion object {
        private const val MONITOR_CHANNEL_ID = "artemis_bg_service_v1"
        private const val ALERT_CHANNEL_ID = "artemis_alerts_v2"
        private const val FOREGROUND_NOTIFICATION_ID = 9001
        private const val PREFS_NAME = "artemis_bg_monitor_prefs"
        private const val PREFS_NOTIFIED_KEY = "notified_ids"
        private var alertNotificationCounter = 2000
    }

    private val running = AtomicBoolean(false)
    private var workerThread: Thread? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
        startForegroundSafely()
        startMonitoringLoop()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForegroundSafely()
        startMonitoringLoop()
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Quando o pai limpa o histórico de abas (Recentes), agenda reinício imediato como o Duolingo
        try {
            val restartIntent = Intent(applicationContext, ArtemisMonitorService::class.java).apply {
                setPackage(packageName)
            }
            val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_ONE_SHOT
            }
            val pendingIntent = PendingIntent.getService(
                applicationContext,
                1,
                restartIntent,
                pendingFlags
            )
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.set(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                SystemClock.elapsedRealtime() + 1500,
                pendingIntent
            )
        } catch (_: Exception) {
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        running.set(false)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val monitorChannel = NotificationChannel(
                MONITOR_CHANNEL_ID,
                "Monitoramento em Segundo Plano Artemis",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Mantém a proteção parental ativa em segundo plano"
                setShowBadge(false)
            }
            manager.createNotificationChannel(monitorChannel)

            val alertChannel = NotificationChannel(
                ALERT_CHANNEL_ID,
                "Alertas de Proteção Artemis",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notificações em tempo real de ciberbullying e links suspeitos"
                enableVibration(true)
                setShowBadge(true)
            }
            manager.createNotificationChannel(alertChannel)
        }
    }

    private fun startForegroundSafely() {
        try {
            val launchIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, pendingFlags)

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, MONITOR_CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }

            val largeIconBitmap = BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher)

            val notification = builder
                .setContentTitle("Artemis Proteção Parental")
                .setContentText("Monitoramento ativo em segundo plano")
                .setSmallIcon(R.drawable.ic_stat_artemis)
                .setLargeIcon(largeIconBitmap)
                .setColor(0xFF0E58A8.toInt())
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .build()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    FOREGROUND_NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                )
            } else {
                startForeground(FOREGROUND_NOTIFICATION_ID, notification)
            }
        } catch (_: Exception) {
        }
    }

    private fun startMonitoringLoop() {
        if (running.getAndSet(true)) return
        workerThread = Thread {
            while (running.get()) {
                try {
                    if (!MainActivity.isInForeground) {
                        checkNewIncidentsInBackground()
                    }
                } catch (_: Exception) {
                }
                try {
                    Thread.sleep(3500)
                } catch (_: InterruptedException) {
                    break
                }
            }
        }.apply {
            isDaemon = true
            start()
        }
    }

    private fun checkNewIncidentsInBackground() {
        val sessionFile = File(filesDir, "artemis_session.json")
        if (!sessionFile.exists()) return

        val rawSession = sessionFile.readText()
        if (rawSession.isBlank()) return

        val sessionJson = JSONObject(rawSession)
        val token = sessionJson.optString("token", "")
        if (token.isBlank() || token.startsWith("mock-")) return

        val savedBaseUrl = sessionJson.optString("base_url", "http://127.0.0.1:8000").trimEnd('/')
        val candidateUrls = linkedSetOf(
            savedBaseUrl,
            "http://127.0.0.1:8000",
            "http://10.69.210.131:8000",
            "http://192.168.1.8:8000",
            "http://10.0.2.2:8000"
        )
        val knownIds = mutableSetOf<String>()

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val savedPrefsSet = prefs.getStringSet(PREFS_NOTIFIED_KEY, emptySet()) ?: emptySet()
        knownIds.addAll(savedPrefsSet)

        val sessionKnownArray = sessionJson.optJSONArray("known_incident_ids")
        if (sessionKnownArray != null) {
            for (i in 0 until sessionKnownArray.length()) {
                val id = sessionKnownArray.optString(i)
                if (id.isNotBlank()) knownIds.add(id)
            }
        }

        for (baseUrl in candidateUrls) {
            if (baseUrl.isBlank()) continue
            var conn: HttpURLConnection? = null
            try {
                val url = URL("$baseUrl/api/v1/incidents?limit=15&offset=0")
                conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    connectTimeout = 1800
                    readTimeout = 2000
                    setRequestProperty("Authorization", "Bearer $token")
                    setRequestProperty("Content-Type", "application/json")
                }

                if (conn.responseCode == 200) {
                    val reader = BufferedReader(InputStreamReader(conn.inputStream))
                    val responseText = reader.use { it.readText() }
                    val bodyJson = JSONObject(responseText)
                    val items: JSONArray = bodyJson.optJSONArray("items") ?: JSONArray()

                    var updated = false
                    for (i in 0 until items.length()) {
                        val inc = items.optJSONObject(i) ?: continue
                        val id = inc.optString("id", "")
                        if (id.isNotBlank() && !knownIds.contains(id)) {
                            knownIds.add(id)
                            updated = true
                            fireIncidentAlertNotification(inc)
                        }
                    }

                    if (updated || baseUrl != savedBaseUrl) {
                        prefs.edit().putStringSet(PREFS_NOTIFIED_KEY, knownIds).apply()
                        try {
                            val newJsonArray = JSONArray()
                            knownIds.forEach { newJsonArray.put(it) }
                            sessionJson.put("known_incident_ids", newJsonArray)
                            sessionJson.put("base_url", baseUrl)
                            sessionFile.writeText(sessionJson.toString())
                        } catch (_: Exception) {
                        }
                    }
                    break
                }
            } catch (_: Exception) {
                continue
            } finally {
                conn?.disconnect()
            }
        }
    }

    private fun fireIncidentAlertNotification(inc: JSONObject) {
        try {
            val severity = inc.optString("severity", "COMUM")
            val category = inc.optString("category", "CIBERBULLYING")
            val dependentName = inc.optString("dependent_name", "Dependente")
            val preview = inc.optString("preview", "Nova mensagem suspeita detectada")
            val confidencePct = (inc.optDouble("confidence", 0.85) * 100.0).roundToInt()

            val isCritical = severity == "CRITICO"
            val isLink = category == "LINK_SUSPEITO"

            val title = when {
                isCritical -> "🚨 ALERTA CRÍTICO: $dependentName"
                isLink -> "⚠️ Link Suspeito: $dependentName"
                else -> "⚠️ Incidente Detectado: $dependentName"
            }
            val body = "$preview (Risco: $confidencePct%)"

            val launchIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pendingIntent = PendingIntent.getActivity(
                this,
                ++alertNotificationCounter,
                launchIntent,
                pendingFlags
            )

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, ALERT_CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this).setPriority(Notification.PRIORITY_MAX)
            }

            val largeIconBitmap = BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher)

            val notification = builder
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(Notification.BigTextStyle().bigText(body))
                .setSmallIcon(R.drawable.ic_stat_artemis)
                .setLargeIcon(largeIconBitmap)
                .setColor(0xFF0E58A8.toInt())
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)
                .build()

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(alertNotificationCounter, notification)
        } catch (_: Exception) {
        }
    }
}
