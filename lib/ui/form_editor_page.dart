import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/api_client.dart';
import '../l10n/app_localizations.dart';

/// One field of a [FormEditorPage]: label on top (DESIGN.md §4 inputs),
/// multi-line growth via [maxLines], input traits, and [obscure] for
/// secrets (an eye toggle reveals it).
class EditorField {
  const EditorField({
    required this.label,
    this.hint = '',
    this.initial = '',
    this.maxLines = 1,
    this.keyboardType,
    this.obscure = false,
    this.autofocus = false,
  });

  final String label;
  final String hint;
  final String initial;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool obscure;
  final bool autofocus;
}

/// Full-screen form editor — the multi-field sibling of KbEditorPage
/// (same surface rules: room for the keyboard, dirty discard guard,
/// save in the app bar). Replaces the cramped add/edit AlertDialogs
/// on a phone. [onSave] returns the pop result (null / throw keeps the
/// page open after an error snack), so callers either return a record
/// for their own repo call or do the call inside and return true.
class FormEditorPage<T> extends StatefulWidget {
  const FormEditorPage({
    super.key,
    required this.heading,
    required this.fields,
    required this.onSave,
    this.canSave,
  });

  final String heading;
  final List<EditorField> fields;
  final Future<T?> Function(List<String> values) onSave;

  /// Save enablement over the current values; null keeps it always on.
  final bool Function(List<String> values)? canSave;

  @override
  State<FormEditorPage> createState() => _FormEditorPageState();
}

class _FormEditorPageState extends State<FormEditorPage> {
  late final List<TextEditingController> _controllers =
      widget.fields.map((f) => TextEditingController(text: f.initial)).toList();
  var _dirty = false;
  var _saving = false;
  final _revealed = <int>{};

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _values => [for (final c in _controllers) c.text];

  Future<void> _save() async {
    if (_saving) return;
    final values = _values;
    if (widget.canSave != null && !widget.canSave!(values)) return;
    setState(() => _saving = true);
    try {
      final result = await widget.onSave(values);
      if (!mounted) return;
      if (result != null) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopScope(
      // Same discard guard as KbEditorPage: dirty text asks before the
      // back gesture throws it away.
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(l.noteDiscard),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.chatDelete)),
            ],
          ),
        );
        if (discard != true) return;
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.heading),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _saving || (widget.canSave?.call(_values) == false) ? null : _save,
                child: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l.settingsSave),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, f) in widget.fields.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                    child: TextField(
                      controller: _controllers[i],
                      autofocus: f.autofocus,
                      maxLines: f.maxLines,
                      keyboardType: f.keyboardType,
                      onChanged: (_) => setState(() => _dirty = true),
                      obscureText: f.obscure && !_revealed.contains(i),
                      decoration: InputDecoration(
                        labelText: f.label,
                        hintText: f.hint.isEmpty ? null : f.hint,
                        suffixIcon: f.obscure
                            ? IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => setState(() {
                                  if (!_revealed.remove(i)) _revealed.add(i);
                                }),
                                icon: Icon(
                                  _revealed.contains(i) ? LucideIcons.eyeOff : LucideIcons.eye,
                                  size: 18,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
