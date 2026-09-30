import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../util/dates.dart';

/// Full-screen text editor for KB items (flash/todo/note). The mobile
/// take on the web's edit dialogs (DESIGN.md §4): editing is a full
/// surface with room for the keyboard, not an alert box squeezing a
/// multi-line field. Optional title field (notes) and due-date row
/// (todos) appear only when configured.
class KbEditorPage extends StatefulWidget {
  const KbEditorPage({
    super.key,
    required this.heading,
    this.hint = '',
    this.initialText = '',
    this.titleLabel,
    this.initialTitle = '',
    this.dateLabel,
    this.initialDate,
    required this.onSave,
  });

  /// AppBar heading (e.g. "新建闪记" / "重命名").
  final String heading;
  final String hint;
  final String initialText;

  /// Optional separate title field (notes). Null hides the field.
  final String? titleLabel;
  final String initialTitle;

  /// Optional due-date row (todos). Null hides the picker.
  final String? dateLabel;
  final DateTime? initialDate;

  /// Returns true when the save succeeded (the page then pops true).
  final Future<bool> Function(String text, String title, DateTime? date) onSave;

  @override
  State<KbEditorPage> createState() => _KbEditorPageState();
}

class _KbEditorPageState extends State<KbEditorPage> {
  late final TextEditingController _text = TextEditingController(text: widget.initialText);
  late final TextEditingController _title = TextEditingController(text: widget.initialTitle);
  DateTime? _date;
  var _dirty = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
  }

  @override
  void dispose() {
    _text.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _text.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final ok = await widget.onSave(_text.text, _title.text, _date);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopScope(
      // Same discard guard the note dialog had: dirty text asks before
      // the back gesture throws it away.
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
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l.settingsSave),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.titleLabel != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    controller: _title,
                    onChanged: (_) => setState(() => _dirty = true),
                    decoration: InputDecoration(labelText: widget.titleLabel),
                  ),
                ),
              if (widget.dateLabel != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          _date = picked;
                          _dirty = true;
                        });
                      }
                    },
                    icon: const Icon(LucideIcons.calendar, size: 16),
                    label: Text(_date == null
                        ? widget.dateLabel!
                        : '${widget.dateLabel} · ${formatShortDate(_date!)}'),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: TextField(
                    controller: _text,
                    onChanged: (_) => setState(() => _dirty = true),
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    autofocus: widget.initialText.isEmpty,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(hintText: widget.hint),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
