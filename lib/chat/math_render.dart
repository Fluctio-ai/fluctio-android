import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

import '../theme/tokens.dart';

/// KaTeX-style math for the chat transcript (same delimiters as the web's
/// @streamdown/math): `$...$` inline, `$$ ... $$` block. Unparseable TeX
/// degrades to the raw LaTeX text instead of crashing (ticket 07).
class MathInlineSyntax extends md.InlineSyntax {
  MathInlineSyntax() : super(r'\$([^$\n]+?)\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('math', match[1]!));
    return true;
  }
}

/// Block-level `$$ ... $$` — the fence either owns whole lines (the TeX
/// body spans lines until the closing fence) or wraps a single line
/// (`$$x=1$$` — common in AI output; without this arm it falls through
/// to the inline syntax and leaks stray `$`s). The TeX rides in
/// attributes, NOT a text child: flutter_markdown 0.7.7+ hands text
/// under a builder-registered block tag to the builder's visitText
/// (null by default), so the pending _InlineElement never fills and
/// never clears — assert crash in debug, "Null check operator" in
/// release.
class MathBlockSyntax extends md.BlockSyntax {
  static final _fence = RegExp(r'^\$\$\s*$');
  static final _singleLine = RegExp(r'^\$\$(.+)\$\$\s*$');
  static final _prefix = RegExp(r'^\$\$');

  @override
  RegExp get pattern => _prefix;

  @override
  md.Node? parse(md.BlockParser parser) {
    final line = parser.current.content;
    final single = _singleLine.firstMatch(line);
    if (single != null) {
      parser.advance();
      return md.Element.empty('mathBlock')..attributes['tex'] = single[1]!.trim();
    }
    final lines = <String>[];
    parser.advance();
    while (!parser.isDone) {
      final l = parser.current.content;
      if (_fence.hasMatch(l)) {
        parser.advance();
        break;
      }
      lines.add(l);
      parser.advance();
    }
    return md.Element.empty('mathBlock')..attributes['tex'] = lines.join('\n');
  }
}

class MathElementBuilder extends MarkdownElementBuilder {
  MathElementBuilder({this.block = false});

  /// Only `$$ ... $$` fences are blocks. An inline `$...$` element must
  /// report false: flutter_markdown 0.7.7+ routes isBlockElement tags into
  /// the block branch mid-paragraph, corrupting the _blocks/_inlines state
  /// machine (assert in debug, "Null check operator" in release).
  final bool block;

  @override
  bool isBlockElement() => block;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    // Block TeX lives in attributes (see MathBlockSyntax); inline TeX in
    // the element's text child. `\ ` (control space) renders as a red
    // missing-glyph box in flutter_math — normalize to `\,`, which it
    // draws cleanly.
    var tex = (block ? element.attributes['tex'] : element.textContent)?.trim() ?? '';
    tex = tex.replaceAll('\\ ', '\\, ');
    if (tex.isEmpty) return const SizedBox.shrink();
    final style = preferredStyle ?? DefaultTextStyle.of(context).style;
    // Parse errors are absorbed by Math.tex's internal fallback (it
    // returns a Math carrying parseError, and onErrorFallback renders
    // the raw LaTeX — ticket 07: never crash).
    final Widget content = Math.tex(
      tex,
      textStyle: style,
      onErrorFallback: (_) => SelectableText(
        tex,
        style: style.copyWith(fontFamily: 'monospace', fontSize: AppType.secondary),
      ),
    );
    // RepaintBoundary: a formula-heavy page repaints every math widget on
    // each scroll frame otherwise. Overwidth guard: blocks scroll
    // horizontally (KaTeX web behavior); inline scales down to fit.
    return RepaintBoundary(
      child: block
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: content),
            )
          : FittedBox(fit: BoxFit.scaleDown, child: content),
    );
  }
}

final mathInlineSyntaxes = [MathInlineSyntax()];
final mathBlockSyntaxes = [MathBlockSyntax()];
final mathBuilders = <String, MarkdownElementBuilder>{
  'math': MathElementBuilder(),
  'mathBlock': MathElementBuilder(block: true),
};
