package ai.fluctio.fluctio_android

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "fluctio/share"
    private val toastChannelName = "fluctio/toast"
    private val notifyChannelName = "fluctio/notify"

    /// Route queued by a notification tap that arrived before Dart was
    /// listening (cold start). Handed over on the channel's first call.
    private var pendingRoute: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notifyChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Opt-in always-on delivery: start/stop the foreground
                    // SSE service with the credentials the UI already holds.
                    "start" -> {
                        val base = call.argument<String>("base") ?: ""
                        val cookie = call.argument<String>("cookie") ?: ""
                        if (base.isEmpty() || cookie.isEmpty()) {
                            result.error("missing-args", "base and cookie required", null)
                        } else {
                            startNotifyService(base, cookie, call.argument<Boolean>("insecure") ?: false)
                            result.success(null)
                        }
                    }
                    "stop" -> {
                        startService(
                            Intent(this, NotifyForegroundService::class.java)
                                .setAction(NotifyForegroundService.ACTION_STOP)
                        )
                        result.success(null)
                    }
                    // Cold start: hand over a route captured from the
                    // launch intent (a tap that arrived while the app was dead).
                    "consumeRoute" -> {
                        result.success(pendingRoute)
                        pendingRoute = null
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Cold start: the launch intent already carries the share.
                    "consume" -> result.success(consumeShare(intent))
                    else -> result.notImplemented()
                }
            }
        // Fire-and-forget confirmations; the system renders the pill.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, toastChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "show" -> {
                        val message = call.argument<String>("message") ?: ""
                        val long = call.argument<Boolean>("long") ?: false
                        Toast.makeText(
                            applicationContext, message,
                            if (long) Toast.LENGTH_LONG else Toast.LENGTH_SHORT
                        ).show()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Cold start from a notification posted by the foreground service:
        // Dart is not listening yet, so park the route for it to pull.
        pendingRoute = intent?.getStringExtra(NotifyForegroundService.EXTRA_ROUTE)
    }

    /// Warm-path method call into Dart; silently drops when no engine is
    /// attached yet (the cold-start paths park state instead).
    private fun push(channel: String, method: String, args: Any?) {
        flutterEngine?.dartExecutor?.binaryMessenger?.let { m ->
            MethodChannel(m, channel).invokeMethod(method, args)
        }
    }

    private fun startNotifyService(base: String, cookie: String, insecure: Boolean) {
        val svc = Intent(this, NotifyForegroundService::class.java)
            .setAction(NotifyForegroundService.ACTION_START)
            .putExtra(NotifyForegroundService.EXTRA_BASE, base)
            .putExtra(NotifyForegroundService.EXTRA_COOKIE, cookie)
            .putExtra(NotifyForegroundService.EXTRA_INSECURE, insecure)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(svc)
        } else {
            startService(svc)
        }
    }

    // Warm arrival while the app is running: hand the intent over and let
    // Dart pull its content via consume.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Live notification tap (foreground-service post): Dart is already
        // attached, so push the route instead of parking it — the parked
        // path is only for a cold start.
        intent.getStringExtra(NotifyForegroundService.EXTRA_ROUTE)?.let { route ->
            push(notifyChannelName, "open", route)
        }
        if (isShare(intent)) {
            push(channelName, "available", null)
        }
    }

    private fun isShare(intent: Intent?): Boolean {
        val action = intent?.action ?: return false
        return action == Intent.ACTION_SEND || action == Intent.ACTION_SEND_MULTIPLE
    }

    /// One inbound share as `{text, items: [{name, mime, dataUrl}]}` —
    /// bytes are read here (Dart can't open content:// URIs) and ride as
    /// base64 data URLs, the same in-memory shape the file picker
    /// produces. Unreadable items come back with an empty dataUrl and are
    /// dropped on the Dart side.
    private fun consumeShare(intent: Intent?): Map<String, Any> {
        if (!isShare(intent)) return mapOf("text" to "", "items" to emptyList<Map<String, String>>())
        val items = mutableListOf<Map<String, String>>()
        @Suppress("DEPRECATION")
        when (intent!!.action) {
            Intent.ACTION_SEND ->
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let {
                    items.add(readItem(it, intent.type))
                }
            Intent.ACTION_SEND_MULTIPLE ->
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.forEach {
                    items.add(readItem(it, intent.type))
                }
        }
        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: ""
        // Mark consumed: a later check must not re-read a stale intent.
        setIntent(Intent())
        return mapOf("text" to text, "items" to items)
    }

    private fun readItem(uri: Uri, intentMime: String?): Map<String, String> {
        val resolver = contentResolver
        val mime = when {
            intentMime != null && intentMime != "*/*" -> intentMime
            else -> resolver.getType(uri) ?: "application/octet-stream"
        }
        var name = ""
        try {
            resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { c ->
                    if (c.moveToFirst()) {
                        val i = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (i >= 0) name = c.getString(i) ?: ""
                    }
                }
        } catch (_: SecurityException) {
        }
        if (name.isEmpty()) name = uri.lastPathSegment ?: "shared-file"
        val dataUrl = try {
            val bytes = resolver.openInputStream(uri)?.use { it.readBytes() }
            if (bytes == null) "" else "data:$mime;base64," +
                android.util.Base64.encodeToString(bytes, android.util.Base64.NO_WRAP)
        } catch (_: Exception) {
            ""
        }
        return mapOf("name" to name, "mime" to mime, "dataUrl" to dataUrl)
    }
}
