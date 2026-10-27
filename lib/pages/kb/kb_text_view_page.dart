import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/markdown.dart';
import '../../files/file_preview.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/load_states.dart';
import '../chat/chat_image.dart';

/// Read-only content viewer for KB text items (flash/note): loads the
/// full stored content — list rows only carry the truncated title — and
/// renders it as markdown with the transcript's exact look. The pencil
/// hands off to the caller's edit flow; a true result reloads.
class KbTextViewPage extends StatefulWidget {
  const KbTextViewPage(
      {super.key, required this.title, required this.loadContent, this.onEdit, this.pathLine, this.topSection});

  final String title;
  final Future<String> Function() loadContent;

  /// Opens the editor for [current]; return true to have the viewer reload.
  final Future<bool> Function(String current)? onEdit;

  /// Optional small source-path line under the app bar (selectable, for
  /// debugging link resolution).
  final String? pathLine;

  /// Optional strip between the app bar and the content (note
  /// attachments).
  final Widget? topSection;

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
      body: KbTextView(future: _future, pathLine: widget.pathLine, topSection: widget.topSection),
    );
  }
}

/// The chromeless body of [KbTextViewPage] — content FutureBuilder +
/// markdown scroll view, no Scaffold/AppBar. Also embedded by the chat
/// page's docked workspace panel for inline text/markdown preview.
class KbTextView extends ConsumerWidget {
  const KbTextView({super.key, required this.future, this.pathLine, this.topSection});

  /// The (already-started) content fetch.
  final Future<String>? future;

  /// Optional small source-path line above the content.
  final String? pathLine;

  /// Optional strip above the content (note attachments).
  final Widget? topSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        ?topSection,
        if (pathLine != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                pathLine!,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
            ),
          ),
        Expanded(
          child: FutureBuilder<String>(
            future: future,
            builder: (context, snap) => snap.connectionState == ConnectionState.waiting
                ? const SkeletonProse()
                : snap.hasError
                    ? ErrorPane(message: AppLocalizations.of(context)!.chatHistoryError)
                    // SliverGptMarkdown splits the document at top-level
                    // blank lines (fences and $$ blocks stay whole — the
                    // package rewrites them to \[...\] first) and lazily
                    // builds only the visible segments: formula-heavy
                    // documents no longer parse TeX for off-screen formulas.
                    : CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: sliverMarkdown(
                              context,
                              snap.data ?? '',
                              // Links and images route through the shared
                              // gateway-file logic (native preview for
                              // /api/agents/.../files, browser otherwise).
                              onTapLink: (href) => openChatLink(context, ref, href),
                              imageBuilder: (context, url, width, height) => MarkdownGatewayImage(
                                url: url,
                                width: width,
                                height: height,
                                onTap: () => openChatLink(context, ref, url),
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        ),
      ],
    );
  }
}
