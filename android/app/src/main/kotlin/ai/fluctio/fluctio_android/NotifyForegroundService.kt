package ai.fluctio.fluctio_android

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.security.SecureRandom
import java.security.cert.X509Certificate
import java.util.concurrent.Executors
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

/// Opt-in always-on delivery for self-hosted gateways, modelled on how
/// Gotify keeps notifications flowing without FCM: hold the server's SSE
/// stream from a foreground service instead of waiting for the
/// WorkManager tick (15-minute floor, OS-deferred under Doze).
///
/// Off by default. The polling path stays the default because it costs
/// nothing while the phone is idle; this service instead pays a permanent
/// notification plus a long-lived connection, and buys sub-second
/// delivery.
///
/// Two consumers of the same queue would race on the cursor-then-ack
/// contract (each holds its own `since`), so when this service runs the
/// Dart side must not attach its own stream — the handover lives in
/// ServerNotificationsService.reconfigureForMode.
///
/// The session cookie is persisted in the app-private preference file so
/// a system restart (START_STICKY) can resume without the UI. Same trust
/// boundary as flutter_secure_storage (app-private storage), lower
/// at-rest strength — documented tradeoff for the restart path.
class NotifyForegroundService : Service() {
    private var worker: Thread? = null

    /// Acks leave the stream thread: a round trip there would stall frame
    /// reading, and the reader has to stay responsive for the server's
    /// 30-second pings.
    private val acker = Executors.newSingleThreadExecutor { r -> Thread(r, "fluctio-notify-ack") }

    @Volatile private var running = false

    private var channelReady = false
    private var insecureFactory: javax.net.ssl.SSLSocketFactory? = null

    private val isZh: Boolean
        get() = resources.configuration.locales[0].language == "zh"

    /// Theme-resolved copy: `isZh` is a getter, so neither value is
    /// captured before the configuration is final.
    private val channelName: String get() = if (isZh) "网关通知" else "Gateway notifications"
    private val channelDescription: String
        get() = if (isZh) "待办提醒、卡片摘要、搁浅话题与日记盲点"
        else "Todo reminders, cards digest, shelved topics and diary blindspots"

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (intent?.action == ACTION_START) {
            prefs().edit()
                .putString(PREF_BASE, intent.getStringExtra(EXTRA_BASE) ?: "")
                .putString(PREF_COOKIE, intent.getStringExtra(EXTRA_COOKIE) ?: "")
                .putBoolean(PREF_INSECURE, intent.getBooleanExtra(EXTRA_INSECURE, false))
                .apply()
        } else if (prefs().getString(PREF_BASE, "").isNullOrEmpty()) {
            // Restart after a process kill with nothing configured.
            stopSelf()
            return START_NOT_STICKY
        }
        start()
        return START_STICKY
    }

    private fun start() {
        if (running) return
        running = true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIF_ID, buildOngoing(), ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIF_ID, buildOngoing())
        }
        worker = Thread({ loop() }, "fluctio-notify-sse").also { it.start() }
    }

    override fun onDestroy() {
        running = false
        worker?.interrupt()
        worker = null
        acker.shutdownNow()
        super.onDestroy()
    }

    /// Reconnect forever with a capped backoff. The stream is long-lived;
    /// a quiet close or a network flap lands here and reconnects.
    private fun loop() {
        var backoffMs = 2_000L
        while (running) {
            try {
                streamOnce()
                backoffMs = 2_000L // a clean stream end means the server is reachable
            } catch (e: InterruptedException) {
                return
            } catch (e: Exception) {
                Log.d(TAG, "stream error: ${e.message}")
            }
            if (!running) return
            try {
                Thread.sleep(backoffMs)
            } catch (e: InterruptedException) {
                return
            }
            backoffMs = (backoffMs * 2).coerceAtMost(60_000L)
        }
    }

    /// One SSE connection: reads frames until the server closes or the
    /// thread is interrupted. Each frame is one notification JSON
    /// (id/agentId/kind/title/body/deepLink) — the same shape the Dart
    /// half parses.
    private fun streamOnce() {
        val (base, cookie) = serverConfig() ?: return
        val since = cursorPrefs().getLong(PREF_CURSOR, 0L)
        val conn = openConnection("$base/api/notifications/stream?since=$since", cookie)
        try {
            conn.connectTimeout = 10_000
            // The server pings every 30s; a longer silence means the socket
            // was black-holed (network handover) and must be re-established.
            conn.readTimeout = 90_000
            conn.connect()
            val reader = BufferedReader(InputStreamReader(conn.inputStream))
            val frame = StringBuilder()
            while (running) {
                val line = reader.readLine() ?: break
                when {
                    // SSE allows multi-line data; join per the spec.
                    line.startsWith("data:") -> {
                        if (frame.isNotEmpty()) frame.append('\n')
                        frame.append(line.removePrefix("data:").trimStart())
                    }
                    line.isEmpty() -> {
                        if (frame.isNotEmpty()) {
                            val payload = frame.toString()
                            frame.setLength(0)
                            handleFrame(payload)
                        }
                    }
                }
            }
        } finally {
            conn.disconnect()
        }
    }

    private fun handleFrame(frame: String) {
        val obj = try {
            JSONObject(frame)
        } catch (e: Exception) {
            return // malformed frame: skip, the cursor did not move
        }
        val id = obj.optLong("id", 0L)
        if (id <= 0L) return
        post(obj.optString("title", "fluctio"), obj.optString("body", ""), obj.optString("deepLink", ""), id)
        // Cursor then ack: a crash between the two replays the row, which
        // is the safe direction (the client drops ids <= cursor).
        cursorPrefs().edit().putLong(PREF_CURSOR, id).apply()
        val watermark = id
        acker.execute { ack(watermark) }
    }

    private fun ack(lastId: Long) {
        val (base, cookie) = serverConfig() ?: return
        try {
            val conn = openConnection("$base/api/notifications/ack", cookie)
            conn.connectTimeout = 10_000
            conn.readTimeout = 10_000
            conn.requestMethod = "POST"
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "application/json")
            conn.outputStream.use { it.write("""{"lastId":$lastId}""".toByteArray()) }
            conn.responseCode // drain
            conn.disconnect()
        } catch (e: Exception) {
            Log.d(TAG, "ack failed: ${e.message}") // row replays next connect
        }
    }

    /// Base URL (no trailing slash) and session cookie, or null when the
    /// service was never configured.
    private fun serverConfig(): Pair<String, String>? {
        val base = prefs().getString(PREF_BASE, "").orEmpty().trimEnd('/')
        val cookie = prefs().getString(PREF_COOKIE, "").orEmpty()
        if (base.isEmpty() || cookie.isEmpty()) return null
        return base to cookie
    }

    /// Builds the connection WITHOUT connecting: callers set the method /
    /// timeouts first — HttpURLConnection rejects that after connect().
    private fun openConnection(url: String, cookie: String): HttpURLConnection {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.setRequestProperty("Accept", "text/event-stream")
        conn.setRequestProperty("Cookie", "fluctio_session=$cookie")
        if (prefs().getBoolean(PREF_INSECURE, false) && conn is HttpsURLConnection) {
            conn.sslSocketFactory = insecureSocketFactory()
            conn.setHostnameVerifier { _, _ -> true }
        }
        return conn
    }

    /// Trust-all factory for self-signed LAN gateways, built once — the
    /// TLS context is expensive and the setting never changes at runtime.
    private fun insecureSocketFactory(): javax.net.ssl.SSLSocketFactory {
        insecureFactory?.let { return it }
        val trustAll = arrayOf<TrustManager>(object : X509TrustManager {
            override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) {}
            override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {}
            override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
        })
        val ctx = SSLContext.getInstance("TLS")
        ctx.init(null, trustAll, SecureRandom())
        return ctx.socketFactory.also { insecureFactory = it }
    }

    private fun manager() = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun openActivity(requestCode: Int, route: String?): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
            if (route != null) {
                action = Intent.ACTION_VIEW
                putExtra(EXTRA_ROUTE, route)
            }
        }
        return PendingIntent.getActivity(
            this, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun post(title: String, body: String, deepLink: String, id: Long) {
        ensureChannel()
        val notif = Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(openActivity(id.toInt(), deepLink))
            .build()
        manager().notify(id.toInt(), notif)
    }

    private fun buildOngoing(): Notification {
        ensureChannel()
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle(if (isZh) "保持后台连接" else "Background connection")
            .setContentText(if (isZh) "通知会实时送达" else "Notifications arrive instantly")
            .setOngoing(true)
            .setContentIntent(openActivity(0, null))
            .build()
    }

    /// Same channel id the Dart half uses, so enabling this mode does not
    /// spawn a second "Gateway notifications" entry in system settings.
    /// High importance matches LocalNotifyHub.messageDetails — one
    /// channel, two posters, so the levels must agree.
    private fun ensureChannel() {
        if (channelReady) return
        val mgr = manager()
        if (mgr.getNotificationChannel(CHANNEL_ID) == null) {
            mgr.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, channelName, NotificationManager.IMPORTANCE_HIGH).apply {
                    description = channelDescription
                },
            )
        }
        channelReady = true
    }

    private fun prefs() = getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE)

    /// The cursor lives in the Dart half's shared_preferences file so
    /// switching delivery modes never replays or skips a row (see
    /// notifyCursorKey in lib/notify/server_notifications.dart).
    private fun cursorPrefs() = getSharedPreferences(CURSOR_FILE, Context.MODE_PRIVATE)

    companion object {
        const val ACTION_START = "ai.fluctio.notify.START"
        const val ACTION_STOP = "ai.fluctio.notify.STOP"
        const val EXTRA_BASE = "base"
        const val EXTRA_COOKIE = "cookie"
        const val EXTRA_INSECURE = "insecure"
        const val EXTRA_ROUTE = "route"

        /// `server_notifications` — the id the Dart half already uses.
        const val CHANNEL_ID = "server_notifications"
        private const val NOTIF_ID = 0x4e4f54 // "NOT" — the ongoing service entry
        private const val TAG = "FluctioNotify"
        private const val PREF_FILE = "fluctio_notify"
        private const val PREF_BASE = "base"
        private const val PREF_COOKIE = "cookie"
        private const val PREF_INSECURE = "insecure"

        /// shared_preferences' Android backend stores into
        /// FlutterSharedPreferences.xml with every key prefixed `flutter.`.
        private const val CURSOR_FILE = "FlutterSharedPreferences"
        private const val PREF_CURSOR = "flutter.notify.cursor"
    }
}
