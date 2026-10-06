import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/load_states.dart';
import '../chat/message_list.dart';

/// Read-only content viewer for KB text items (flash/note): loads the
/// full stored content — list rows only carry the truncated title — and
/// renders it as markdown with the transcript's exact look. The pencil
/// hands off to the caller's edit flow; a true result reloads.
class KbTextViewPage extends StatefulWidget {
  const KbTextViewPage({super.key, required this.title, required this.loadContent, this.onEdit, this.pathLine});

  final String title;
  final Future<String> Function() loadContent;

  /// Opens the editor for [current]; return true to have the viewer reload.
  final Future<bool> Function(String current)? onEdit;

  /// Optional small source-path line under the app bar (selectable, for
  /// debugging link resolution).
  final String? pathLine;

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
    if (changed && mounted) {
      // Block body — an arrow closure would return the assigned Future
      // and trip setState's callback-returned-a-Future assertion.
      final next = widget.loadContent();
      setState(() {
        _future = next;
      });
    }
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
      body: Column(
        children: [
          if (widget.pathLine != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  widget.pathLine!,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: Theme.of(context).colorScheme.outline),
                ),
              ),
            ),
          Expanded(
            child: FutureBuilder<String>(
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
                    child: transcriptMarkdown(context, snap.data ?? ''),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
