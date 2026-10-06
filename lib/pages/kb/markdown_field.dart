import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../util/markdown_lint.dart';

/// VSCode-style markdown editing surface: syntax highlighting, a
/// line-number gutter, and a lint strip (unclosed fences, unpaired
/// inline math, ragged tables) that opens a jump-to-line issue list.
///
/// The [controller] is owned by the caller (save/dirty flows live in
/// the page). Only TEXT changes surface through [onChanged] — the
/// controller also notifies on cursor moves, which must not dirty the
/// document or re-lint. Lint runs here, not in the page: keystrokes
/// rebuild only this widget's strip, not the page around it.
class MarkdownField extends StatefulWidget {
  const MarkdownField({
    super.key,
    required this.controller,
    this.hint,
    this.autofocus = false,
    this.onChanged,
  });

  final CodeLineEditingController controller;
  final String? hint;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  State<MarkdownField> createState() => _MarkdownFieldState();
}

class _MarkdownFieldState extends State<MarkdownField> {
  String _lintedText = '';
  List<MdIssue> _issues = const [];
  CodeEditorStyle? _cachedStyle;
  Brightness? _cachedBrightness;

  @override
  void initState() {
    super.initState();
    _lintedText = widget.controller.text;
    _issues = lintMarkdown(_lintedText);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final text = widget.controller.text;
    if (text == _lintedText) return; // Selection/cursor move only.
    _lintedText = text;
    widget.onChanged?.call(text);
    final issues = lintMarkdown(text);
    if (listEquals(issues, _issues)) return;
    setState(() => _issues = issues);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: CodeEditor(
            controller: widget.controller,
            wordWrap: true,
            autofocus: widget.autofocus,
            hint: widget.hint,
            style: _styleOf(context),
            indicatorBuilder: (context, editingController, chunkController, notifier) =>
                DefaultCodeLineNumber(
              controller: editingController,
              notifier: notifier,
              textStyle: TextStyle(
                fontSize: AppType.caption,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ),
        if (_issues.isNotEmpty) _issuesStrip(context),
      ],
    );
  }

  /// The style (highlight theme included) must be a stable instance:
  /// a fresh one per build makes the editor re-highlight the whole
  /// document on every keystroke. Cached per brightness.
  CodeEditorStyle _styleOf(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (_cachedStyle != null && _cachedBrightness == brightness) {
      return _cachedStyle!;
    }
    final theme = Theme.of(context);
    final base =
        brightness == Brightness.dark ? atomOneDarkTheme : atomOneLightTheme;
    // The bundled themes paint their own background — keep the page's.
    final colors = {...base, 'root': base['root']!.copyWith(backgroundColor: null)};
    final style = CodeEditorStyle(
      fontFamily: 'monospace',
      fontSize: AppType.body,
      textColor: theme.colorScheme.onSurface,
      backgroundColor: Colors.transparent,
      cursorColor: theme.colorScheme.primary,
      selectionColor: theme.colorScheme.primary.withValues(alpha: 0.2),
      codeTheme: CodeHighlightTheme(
        languages: {
          'markdown': CodeHighlightThemeMode(mode: langMarkdown),
        },
        theme: colors,
      ),
    );
    _cachedBrightness = brightness;
    return _cachedStyle = style;
  }

  /// The lint strip: issue count, tap to list issues and jump to one.
  Widget _issuesStrip(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasErrors = _issues.any((i) => i.isError);
    final color = hasErrors ? scheme.error : paletteOf(context).warning;
    return InkWell(
      onTap: () => _showIssues(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border(top: BorderSide(color: color.withValues(alpha: 0.3))),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.triangleAlert, size: 14, color: color),
            const SizedBox(width: 6),
            Text(l.editorIssues(_issues.length),
                style: theme.textTheme.bodySmall?.copyWith(color: color)),
            const Spacer(),
            const Icon(LucideIcons.chevronRight, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _showIssues(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                child: Text(l.editorIssues(_issues.length),
                    style: theme.textTheme.labelLarge),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final issue in _issues)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          issue.isError
                              ? LucideIcons.circleAlert
                              : LucideIcons.triangleAlert,
                          size: 16,
                          color: issue.isError
                              ? theme.colorScheme.error
                              : paletteOf(sheetContext).warning,
                        ),
                        title: Text(_issueMessage(issue, l)),
                        trailing: Text(l.editorIssueGo(issue.line + 1),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.outline)),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          // Setting the selection scrolls the editor's
                          // cursor into view — exact, unlike pixel math
                          // that breaks on word-wrapped lines.
                          widget.controller.selection =
                              CodeLineSelection.collapsed(
                                  index: issue.line, offset: 0);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _issueMessage(MdIssue issue, AppLocalizations l) => switch (issue.kind) {
        MdIssueKind.unclosedCodeFence => l.editorLintUnclosedCodeFence,
        MdIssueKind.unclosedMathFence => l.editorLintUnclosedMathFence,
        MdIssueKind.oddDollars => l.editorLintOddDollars,
        MdIssueKind.tableColumns => l.editorLintTableColumns,
      };
}
