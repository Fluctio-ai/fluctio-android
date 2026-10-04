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
    this.initialStatus = '',
    this.statusOptions = const [],
    this.dateLabel,
    this.initialDate,
    this.endDateLabel,
    this.initialEndDate,
    required this.onSave,
  });

  /// AppBar heading (e.g. "新建闪记" / "重命名").
  final String heading;
  final String hint;
  final String initialText;

  /// Optional separate title field (notes). Null hides the field.
  final String? titleLabel;
  final String initialTitle;

  /// Optional status segment row (todos): the current status id plus
  /// the selectable (id, label) pairs. An empty initialStatus hides the
  /// row — note/flash editors never see it.
  final String initialStatus;
  final List<(String, String)> statusOptions;

  /// Optional start-date row (todos). Null hides the picker.
  final String? dateLabel;
  final DateTime? initialDate;

  /// Optional end-date row (todo spans, web's 开始/结束时间 pair). Null
  /// hides the picker.
  final String? endDateLabel;
  final DateTime? initialEndDate;

  /// Returns true when the save succeeded (the page then pops true).
  /// [endDate] arrives only for todo editors that configured the end
  /// row; other callers ignore it. [status] likewise arrives only for
  /// todo editors that configured the status row.
  final Future<bool> Function(String text, String title, DateTime? date,
      DateTime? endDate, {String? status}) onSave;

  @override
  State<KbEditorPage> createState() => _KbEditorPageState();
}

class _KbEditorPageState extends State<KbEditorPage> {
  late final TextEditingController _text = TextEditingController(text: widget.initialText);
  late final TextEditingController _title = TextEditingController(text: widget.initialTitle);
  late String _status = widget.initialStatus;
  DateTime? _date;
  DateTime? _endDate;
  var _dirty = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _endDate = widget.initialEndDate;
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
    final ok = await widget.onSave(_text.text, _title.text, _date, _endDate,
        status: _status.isEmpty ? null : _status);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop(true);
  }

  /// Web-parity datetime picking (web uses datetime-local inputs):
  /// date first, then the time-of-day; cancelling the time keeps
  /// midnight.
  Future<void> _pickDate(bool isEnd) async {
    final current = isEnd ? _endDate : _date;
    final d = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? DateTime(d.year, d.month, d.day, 9)),
    );
    if (!mounted) return;
    setState(() {
      final picked = DateTime(d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0);
      if (isEnd) {
        _endDate = picked;
      } else {
        _date = picked;
      }
      _dirty = true;
    });
  }

  /// The status segment row (todos): the same SegmentedButton idiom as
  /// the page's view switcher; a pick marks the page dirty like any
  /// other edit.
  Widget _statusRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SegmentedButton<String>(
        segments: [
          for (final (id, label) in widget.statusOptions)
            ButtonSegment(
                value: id,
                label: Text(label,
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
        selected: {_status},
        showSelectedIcon: false,
        onSelectionChanged: (s) => setState(() {
          _status = s.first;
          _dirty = true;
        }),
      ),
    );
  }

  /// One start/end datetime row: pick button + clear button when set.
  Widget _dateRow(bool isEnd) {
    final value = isEnd ? _endDate : _date;
    final label = isEnd ? widget.endDateLabel! : widget.dateLabel!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: () => _pickDate(isEnd),
              icon: const Icon(LucideIcons.calendar, size: 16),
              label: Text(value == null
                  ? label
                  : '$label · ${formatShortDate(value, withTime: true)}'),
            ),
          ),
          if (value != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '清除',
              onPressed: () => setState(() {
                if (isEnd) {
                  _endDate = null;
                } else {
                  _date = null;
                }
                _dirty = true;
              }),
              icon: const Icon(LucideIcons.x, size: 16),
            ),
        ],
      ),
    );
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
              if (widget.statusOptions.isNotEmpty) _statusRow(),
              if (widget.dateLabel != null) _dateRow(false),
              if (widget.endDateLabel != null) _dateRow(true),
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
