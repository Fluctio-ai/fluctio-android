import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:markdown/markdown.dart' as md;

import '../../l10n/app_localizations.dart';
import '../../ui/load_states.dart';
import '../chat/message_list.dart';

/// Read-only content viewer for KB text items (flash/note): loads the
/// full stored content — list rows only carry the truncated title — and
/// renders it as markdown with the transcript's exact look. The pencil
/// hands off to the caller's edit flow; a true result reloads.
class KbTextViewPage extends StatefulWidget {
  const KbTextViewPage({super.key, required this.title, required this.loadContent, this.onEdit});

  final String title;
  final Future<String> Function() loadContent;

  /// Opens the editor for [current]; return true to have the viewer reload.
  final Future<bool> Function(String current)? onEdit;

  @override
  State<KbTextViewPage> createState() => _KbTextViewPageState();
}

class _KbTextViewPageState extends State<KbTextViewPage> {
  Future<String>? _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loadContent();
  }

  Future<void> _edit() async {
    final current = await _future;
    if (!mounted || current == null || widget.onEdit == null) return;
    final changed = await widget.onEdit!(current);
    if (changed && mounted) setState(() => _future = widget.loadContent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.onEdit != null)
            IconButton(
              tooltip: AppLocalizations.of(context)!.kbEdit,
              icon: const Icon(LucideIcons.penLine, size: 20),
              onPressed: _edit,
            ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _future,
        builder: (context, snap) => snap.connectionState == ConnectionState.waiting
            ? const SkeletonProse()
            : snap.hasError
                ? ErrorPane(message: AppLocalizations.of(context)!.chatHistoryError)
                : SingleChildScrollView(
                    // MarkdownBody is non-scrolling on its own — without
                    // this wrapper long content overflows (yellow-black
                    // stripes) and can't be scrolled.
                    padding: const EdgeInsets.all(16),
                    child: MarkdownBody(
                      data: snap.data ?? '',
                      extensionSet: md.ExtensionSet.gitHubWeb,
                      builders: markdownBuilders,
                      styleSheet: markdownStyle(context),
                    ),
                  ),
      ),
    );
  }
}
