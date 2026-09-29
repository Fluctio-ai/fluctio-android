import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

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

/// Block-level `$$\n...\n$$` — consumes lines between the fences.
class MathBlockSyntax extends md.BlockSyntax {
  static final _fence = RegExp(r'^\$\$\s*$');

  @override
  RegExp get pattern => _fence;

  @override
  md.Node? parse(md.BlockParser parser) {
    final lines = <String>[];
    parser.advance();
    while (!parser.isDone) {
      final line = parser.current.content;
      if (_fence.hasMatch(line)) {
        parser.advance();
        break;
      }
      lines.add(line);
      parser.advance();
    }
    return md.Element('mathBlock', [md.Text(lines.join('\n'))]);
  }
}

class MathElementBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final tex = element.textContent.trim();
    if (tex.isEmpty) return const SizedBox.shrink();
    final style = preferredStyle ?? DefaultTextStyle.of(context).style;
    try {
      // Parse errors surface at build time, not here — onErrorFallback
      // renders the raw LaTeX (ticket 07: never crash).
      return Math.tex(
        tex,
        textStyle: style,
        onErrorFallback: (_) => SelectableText(
          tex,
          style: style.copyWith(fontFamily: 'monospace', fontSize: 13),
        ),
      );
    } catch (_) {
      return SelectableText(
        tex,
        style: style.copyWith(fontFamily: 'monospace', fontSize: 13),
      );
    }
  }
}

final mathInlineSyntaxes = [MathInlineSyntax()];
final mathBlockSyntaxes = [MathBlockSyntax()];
final mathBuilders = <String, MarkdownElementBuilder>{
  'math': MathElementBuilder(),
  'mathBlock': MathElementBuilder(),
};
