import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

import '../theme/tokens.dart';
import 'file_kind.dart';

const _codeFontFamily = codeMonoFamily;

/// Read-only syntax-highlighted source viewer for workspace files.
/// re_editor in readOnly mode: virtualized chunks (large files stay
/// smooth), literal indentation, soft word-wrap — none of the markup
/// interpretation that made .py files render as broken markdown.
///
/// One instance per file: callers key the widget by path so content and
/// [fileName] never change under a live State (the controller and
/// highlight mode are built once in initState).
class CodeViewer extends StatefulWidget {
  const CodeViewer({super.key, required this.content, this.fileName});

  /// Full file text (already fetched by the caller).
  final String content;

  /// File name (or path) resolving the highlight language via
  /// [highlightModeFor]; unknown names render plaintext.
  final String? fileName;

  @override
  State<CodeViewer> createState() => _CodeViewerState();
}

class _CodeViewerState extends State<CodeViewer> {
  /// Split off the UI thread (fromTextAsync runs the parse in an
  /// isolate) — a multi-MB log would otherwise freeze the pushed route's
  /// first frame (~30-60ms/MB).
  late final CodeLineEditingController _controller;

  /// Resolved once on first access; [fileName] never changes under a
  /// live State (callers key by path).
  late final Mode _mode = highlightModeFor(widget.fileName ?? '');

  CodeEditorStyle? _cachedStyle;
  TextStyle? _cachedGutterStyle;

  @override
  void initState() {
    super.initState();
    _controller = CodeLineEditingController.fromTextAsync(widget.content);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Stable style instance per resolved inputs — a fresh one per build
  /// makes the editor re-highlight the whole document on every rebuild
  /// (same lesson as MarkdownField's editor). Keyed on the colors and
  /// size actually baked in, so a brightness or font-tier change
  /// rebuilds exactly once. (Two consumers key their caches
  /// independently — a shared brightness field froze the gutter style
  /// after the first build.)
  CodeEditorStyle _styleOf(ThemeData theme, double fontSize) {
    final cached = _cachedStyle;
    if (cached != null &&
        cached.fontSize == fontSize &&
        cached.textColor == theme.colorScheme.onSurface) {
      return cached;
    }
    final base = theme.brightness == Brightness.dark
        ? atomOneDarkTheme
        : atomOneLightTheme;
    // The bundled themes paint their own background — keep the page's.
    final colors = {...base, 'root': base['root']!.copyWith(backgroundColor: null)};
    final style = CodeEditorStyle(
      fontFamily: _codeFontFamily,
      fontSize: fontSize,
      textColor: theme.colorScheme.onSurface,
      backgroundColor: Colors.transparent,
      selectionColor: theme.colorScheme.primary.withValues(alpha: 0.2),
      codeTheme: CodeHighlightTheme(
        languages: {'lang': CodeHighlightThemeMode(mode: _mode)},
        theme: colors,
      ),
    );
    return _cachedStyle = style;
  }

  TextStyle _gutterStyleOf(ThemeData theme, double fontSize) {
    final color = theme.colorScheme.outline;
    final cached = _cachedGutterStyle;
    if (cached != null &&
        cached.fontSize == fontSize &&
        cached.color == color) {
      return cached;
    }
    return _cachedGutterStyle =
        TextStyle(fontSize: fontSize, fontFamily: _codeFontFamily, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // re_editor never consults the ambient TextScaler (it lays its own
    // text out), so the One Scale Rule is wired here: the tier scales
    // the input sizes.
    final scaler = MediaQuery.textScalerOf(context);
    // Transcript step, not secondary: a workspace file previewed here
    // must match the same file's fenced block in a chat bubble (markdown
    // pins code to the surface body — ticket 10 made that 13.5 everywhere).
    final bodySize = scaler.scale(AppType.transcript);
    final gutterSize = scaler.scale(AppType.caption);
    return CodeEditor(
      controller: _controller,
      readOnly: true,
      wordWrap: true,
      // The editor defaults autofocus to true and steals focus from the
      // composer on mount — a preview pane must stay focus-silent.
      autofocus: false,
      style: _styleOf(theme, bodySize),
      indicatorBuilder: (context, editingController, chunkController, notifier) =>
          DefaultCodeLineNumber(
        controller: editingController,
        notifier: notifier,
        textStyle: _gutterStyleOf(theme, gutterSize),
      ),
    );
  }
}
