package ai.fluctio.fluctio_android

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "fluctio/share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Cold start: the launch intent already carries the share.
                    "consume" -> result.success(consumeShare(intent))
                    else -> result.notImplemented()
                }
            }
    }

    // Warm arrival while the app is running: hand the intent over and let
    // Dart pull its content via consume.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (isShare(intent)) {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { m ->
                MethodChannel(m, channelName).invokeMethod("available", null)
            }
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
