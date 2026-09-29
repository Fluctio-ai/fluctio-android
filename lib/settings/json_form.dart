import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';

/// Generic editor for free-form settings blobs (vectorization / privacy /
/// recall-tuning / usage): bool → switch, num → numeric field, string →
/// text field, `List<String>` → tag editor, nested map → section. Values
/// round-trip untouched for keys we don't render.
class JsonForm extends StatelessWidget {
  const JsonForm({super.key, required this.value, required this.onChanged, this.hiddenKeys = const {}});

  final Map<String, dynamic> value;
  final void Function(Map<String, dynamic> next) onChanged;

  /// Keys present in [value] but neither rendered nor editable — they
  /// ride along untouched on every onChanged (credential namespaces that
  /// the server masks and that must round-trip verbatim).
  final Set<String> hiddenKeys;

  void _set(String key, Object? v) => onChanged({...value, key: v});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in value.entries)
          if (!hiddenKeys.contains(entry.key))
            _field(context, theme, entry.key, entry.value),
      ],
    );
  }

  Widget _field(BuildContext context, ThemeData theme, String key, Object? v) {
    if (v is bool) {
      return SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: Text(key, style: theme.textTheme.bodyMedium),
        value: v,
        onChanged: (next) => _set(key, next),
      );
    }
    if (v is num) {
      return _labeled(
        context,
        key,
        TextField(
          controller: TextEditingController(text: '$v')
            ..selection = TextSelection.collapsed(offset: '$v'.length),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
          ],
          decoration: const InputDecoration(isDense: true),
          onChanged: (text) {
            final parsed = int.tryParse(text) ?? double.tryParse(text);
            if (parsed != null) _set(key, parsed);
          },
        ),
      );
    }
    if (v is String) {
      return _labeled(
        context,
        key,
        TextField(
          controller: TextEditingController(text: v),
          decoration: const InputDecoration(isDense: true),
          onChanged: (text) => _set(key, text),
        ),
      );
    }
    if (v is List && v.every((e) => e is String)) {
      return _labeled(context, key, _TagEditor(tags: v.cast<String>(), onChanged: (next) => _set(key, next)));
    }
    if (v is Map) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(key,
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: 4),
            JsonForm(
              value: Map<String, dynamic>.from(v),
              onChanged: (next) => _set(key, next),
            ),
          ],
        ),
      );
    }
    return _labeled(
      context,
      key,
      Text(v == null ? 'null' : '$v', style: theme.textTheme.bodySmall),
    );
  }

  Widget _labeled(BuildContext context, String label, Widget field) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          field,
        ],
      ),
    );
  }
}

/// Comma-separated editor for `List<String>` settings (keywords etc.).
class _TagEditor extends StatefulWidget {
  const _TagEditor({required this.tags, required this.onChanged});

  final List<String> tags;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<_TagEditor> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.tags.join(', '));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            isDense: true,
            suffixIcon: IconButton(
              icon: const Icon(LucideIcons.check, size: 16),
              onPressed: () => widget.onChanged(
                _controller.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
              ),
            ),
          ),
        ),
        if (widget.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              children: [
                for (final tag in widget.tags.take(8))
                  Chip(
                    label: Text(tag, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: theme.colorScheme.secondaryContainer,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Read-only rendering for opaque payloads (usage stats etc.).
class JsonView extends StatelessWidget {
  const JsonView({super.key, required this.value});

  final Map<String, dynamic> value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in value.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(entry.key,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline)),
                ),
                const SizedBox(width: 12),
                Flexible(child: Text('${entry.value}', style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Reusable save bar for blob tabs.
class BlobSaveBar extends StatelessWidget {
  const BlobSaveBar({super.key, required this.dirty, required this.onSave, required this.saving});

  final bool dirty;
  final VoidCallback onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.controlBorder),
          ),
          onPressed: dirty && !saving ? onSave : null,
          icon: saving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(LucideIcons.save, size: 16),
          label: Text(l.settingsSave),
        ),
      ),
    );
  }
}
