import 'package:flutter/material.dart';

/// Small selectable source-path line shown under an app bar in preview
/// surfaces (KbTextView, file_preview's textPreviewBody) — debugging
/// chrome: the actual resolved path, copyable.
class PathLine extends StatelessWidget {
  const PathLine(this.path, {super.key});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SelectableText(
          path,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }
}
