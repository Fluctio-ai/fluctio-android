import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../auth/session_cookie.dart';
import '../l10n/app_localizations.dart';
import 'local_web_server.dart';

/// Web-app routes the native app embeds in the fallback container — the
/// WebView-fallback contract in one place (a web-side rename breaks here,
/// visibly, instead of at four inline call sites).
abstract final class WebRoutes {
  static String wiki(String agentId) => '/agents/$agentId/wiki';
  static String workflows(String agentId) => '/agents/$agentId/workflows';
  static String noteEditor(String agentId) => '/agents/$agentId/knowledge/notes';
  static String diagnostics() => '/settings/diag';
}

/// Generic WebView fallback container (ticket 10): expensive features
/// (whiteboard / graph / workflow editor / diagnostics) load the web app
/// inside a WebView instead of a native rewrite. Auth is the session
/// cookie, injected via WebViewCookieManager before the first load —
/// the same mechanism the browser uses, so no token-in-URL exposure.
class WebContainerPage extends ConsumerStatefulWidget {
  const WebContainerPage({super.key, required this.title, required this.path, this.showTitle = true});

  final String title;
  final String path;

  /// False hides the app bar entirely — for web pages that carry their
  /// own title/back header (Workflows), so the two never stack up.
  final bool showTitle;

  @override
  ConsumerState<WebContainerPage> createState() => _WebContainerPageState();
}

class _WebContainerPageState extends ConsumerState<WebContainerPage> {
  WebViewController? _controller;
  int _stackIndex = 0; // 0 = loading, 1 = content, 2 = error
  bool _local = false;
  double _progress = 0;

  Future<void> _load() async {
    final auth = ref.read(authControllerProvider);
    final base = Uri.tryParse(auth.baseUrl);
    if (base == null) {
      setState(() => _stackIndex = 2);
      return;
    }
    // Route A (bundled webui): serve the next-export snapshot from
    // assets through the local loopback server — instant loads, no
    // self-signed TLS, /api proxied with the session cookie. Absent
    // snapshot falls back to the live site with cookie injection.
    var target = '${auth.baseUrl}${widget.path}';
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (await _hasBundledWebUi()) {
      LocalWebServer.instance.configure(ref.read(apiClientProvider), auth.sid, dark: dark);
      target = await LocalWebServer.instance.urlFor(widget.path);
      _local = true;
    } else {
      // Inject the session cookie for the gateway host (token spike result:
      // cookie injection — the web pages authenticate exactly like a
      // browser; URL params and localStorage are not needed).
      final cookieManager = WebViewCookieManager();
      if (auth.sid != null && auth.sid!.isNotEmpty) {
        await cookieManager.setCookie(sessionWebViewCookie(auth.sid!, base));
      }
    }
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            // Progress fires dozens of times per load; only rebuild on
            // meaningful deltas.
            final v = p / 100.0;
            if (v - _progress >= 0.1 || v >= 1.0) setState(() => _progress = v);
          },
          onPageFinished: (_) {
            setState(() => _stackIndex = 1);
            // Match the app's theme (ThemeMode.system): the web app
            // drives dark mode via a `.dark` class on <html>, not
            // prefers-color-scheme, so sync it here. Also hides the web
            // app's own sidebar (trigger + container) — the app already
            // owns navigation (drawer/tabs). Re-injected per navigation.
            final dark = Theme.of(context).brightness == Brightness.dark;
            _controller?.runJavaScript('''
(function(){
  document.documentElement.classList.${dark ? 'add' : 'remove'}('dark');
  var s=document.createElement('style');
  s.id='fluctio-hide-sidebar';
  s.textContent='[data-sidebar="trigger"]{display:none!important}'
    +'[data-slot="sidebar-container"]{display:none!important}'
    +'[data-slot="sidebar-inset"]{margin:0!important;min-width:0!important}';
  if(!document.getElementById('fluctio-hide-sidebar')) document.head.appendChild(s);
})();
''');
          },
          onWebResourceError: (e) {
            if (e.isForMainFrame == true && _stackIndex != 1) {
              setState(() => _stackIndex = 2);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(target));
    // NOTE: self-signed LAN servers are a documented limitation of the
    // WebView container (the platform view enforces its own certificate
    // checks; no hook to bypass without a custom trust manager).
    setState(() {
      _controller = controller;
      _stackIndex = 0;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<bool> _hasBundledWebUi() async {
    try {
      await rootBundle.load('assets/webui.zip');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // No app-bar back button: the embedded web pages carry their own
    // back affordance, so an automatic leading arrow doubled it up. The
    // system gesture/back key walks the web history first, then pops
    // the container.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final c = _controller;
        if (c != null && await c.canGoBack()) {
          await c.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      appBar: widget.showTitle ? AppBar(title: Text(widget.title)) : null,
      body: IndexedStack(
        index: _stackIndex,
        children: [
          // 0: loading — blank in local mode (assets answer in
          // milliseconds; a spinner flash is pure noise). Online keeps
          // the progress view.
          _local
              ? const SizedBox.expand()
              : Center(
                  child: SizedBox(
                    width: 180,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LinearProgressIndicator(value: _progress == 0 ? null : _progress),
                        const SizedBox(height: 8),
                        Text(l.webLoading, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
          // 1: content
          _controller == null
              ? const SizedBox.shrink()
              : WebViewWidget(controller: _controller!),
          // 2: error
          _ErrorView(
            onRetry: _load,
            onRelogin: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry, required this.onRelogin});

  final VoidCallback onRetry;
  final VoidCallback onRelogin;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.wifiOff, size: 40, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(l.webLoadFailed, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(l.webReloginHint,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(onPressed: onRetry, child: Text(l.chatLoadAgents)),
              const SizedBox(width: 12),
              FilledButton(onPressed: onRelogin, child: Text(l.signOut)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Push helper used by the five fallback entry points.
void openWebContainer(BuildContext context, String title, String path) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => WebContainerPage(title: title, path: path)),
  );
}

/// Full-screen mermaid renderer: a tiny local HTML page loading mermaid
/// from CDN and rendering the given source; the cookie is irrelevant
/// here so a plain WebView suffices.
class MermaidViewerPage extends StatefulWidget {
  const MermaidViewerPage({super.key, required this.source});

  final String source;

  @override
  State<MermaidViewerPage> createState() => _MermaidViewerPageState();
}

class _MermaidViewerPageState extends State<MermaidViewerPage> {
  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..loadHtmlString(_html(widget.source), baseUrl: 'https://cdn.jsdelivr.net/');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }

  String _html(String src) {
    final escaped = src
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
<style>
  body { margin: 0; padding: 12px; background: #fff; font-family: sans-serif; }
  .mermaid { display: flex; justify-content: center; }
</style>
</head>
<body>
<pre class="mermaid">$escaped</pre>
<script>
  mermaid.initialize({ startOnLoad: true, theme: 'default' });
</script>
</body>
</html>
''';
  }
}

void openMermaidViewer(BuildContext context, String source) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => MermaidViewerPage(source: source)),
  );
}
