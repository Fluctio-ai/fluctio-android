import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/api_client.dart';
import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';

/// Generic editor for free-form settings blobs (vectorization / privacy /
/// recall-tuning): bool → switch, num → numeric field, string → text
/// field, `List<String>` → tag editor, nested map → section. Keys listed
/// in [hiddenKeys] ride along untouched on every change (credential
/// namespaces the server masks and that must round-trip verbatim).
class JsonForm extends StatelessWidget {
  const JsonForm({
    super.key,
    required this.value,
    required this.onChanged,
    this.hiddenKeys = const {},
  });

  final Map<String, dynamic> value;
  final void Function(Map<String, dynamic> next) onChanged;
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
      return labeledField(
        context,
        key,
        _NumField(initial: v, onChanged: (parsed) => _set(key, parsed)),
      );
    }
    if (v is String) {
      return labeledField(
        context,
        key,
        _StrField(initial: v, onChanged: (text) => _set(key, text)),
      );
    }
    if (v is List && v.every((e) => e is String)) {
      return labeledField(
        context,
        key,
        _TagEditor(tags: v.cast<String>(), onChanged: (next) => _set(key, next)),
      );
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
              hiddenKeys: hiddenKeys,
              onChanged: (next) => _set(key, next),
            ),
          ],
        ),
      );
    }
    return labeledField(
      context,
      key,
      Text(v == null ? 'null' : '$v', style: theme.textTheme.bodySmall),
    );
  }
}

/// Label over a form field — shared with the hand-built settings tabs.
Widget labeledField(BuildContext context, String label, Widget field) {
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

/// Field owning its controller (a fresh controller per build would lose
/// the cursor and leak ChangeNotifiers on every parent setState).
class _StrField extends StatefulWidget {
  const _StrField({required this.initial, required this.onChanged});

  final String initial;
  final void Function(String text) onChanged;

  @override
  State<_StrField> createState() => _StrFieldState();
}

class _StrFieldState extends State<_StrField> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: const InputDecoration(isDense: true),
      onChanged: widget.onChanged,
    );
  }
}

class _NumField extends StatefulWidget {
  const _NumField({required this.initial, required this.onChanged});

  final num initial;
  final void Function(num parsed) onChanged;

  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final _controller = TextEditingController(text: '${widget.initial}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
      decoration: const InputDecoration(isDense: true),
      onChanged: (text) {
        final parsed = int.tryParse(text) ?? double.tryParse(text);
        if (parsed != null) widget.onChanged(parsed);
      },
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
                _controller.text
                    .split(',')
                    .map((t) => t.trim())
                    .where((t) => t.isNotEmpty)
                    .toList(),
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

/// Reusable save bar for blob editors.
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

/// The blob-editor state machine in one place: load → JsonForm → save,
/// shared by the agent settings tabs (recall / vectorization / privacy)
/// and the system settings screens.
class BlobEditor extends StatefulWidget {
  const BlobEditor({
    super.key,
    required this.load,
    required this.save,
    this.hiddenKeys = const {},
  });

  final Future<Map<String, dynamic>> Function() load;
  final Future<void> Function(Map<String, dynamic> blob) save;
  final Set<String> hiddenKeys;

  @override
  State<BlobEditor> createState() => _BlobEditorState();
}

class _BlobEditorState extends State<BlobEditor> {
  Map<String, dynamic>? _blob;
  bool _dirty = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final blob = await widget.load();
      if (!mounted) return;
      setState(() => _blob = blob);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.save(_blob!);
      if (mounted) setState(() => _dirty = false);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_error != null) {
      return Center(child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)));
    }
    final blob = _blob;
    if (blob == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JsonForm(
          value: blob,
          hiddenKeys: widget.hiddenKeys,
          onChanged: (next) => setState(() {
            _blob = next;
            _dirty = true;
          }),
        ),
        BlobSaveBar(dirty: _dirty, saving: _saving, onSave: _save),
      ],
    );
  }
}
