import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:re_editor/re_editor.dart';

import '../../l10n/app_localizations.dart';
import '../../util/dates.dart';
import 'markdown_field.dart';
import 'todo_views.dart';

/// Full-screen text editor for KB items (flash/todo/note). The mobile
/// take on the web's edit dialogs (DESIGN.md §4): editing is a full
/// surface with room for the keyboard, not an alert box squeezing a
/// multi-line field. Optional title field (notes) and due-date row
/// (todos) appear only when configured. The body is [MarkdownField]:
/// VSCode-style highlighting, line numbers and lint.
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
  late final CodeLineEditingController _text =
      CodeLineEditingController.fromText(widget.initialText);
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

  /// The status row (todos): current status with a semantic dot
  /// (todoStatusColor, shared with the calendar/gantt dots), tap to
  /// pick from a bottom sheet. Replaced the inline SegmentedButton
  /// (user feedback): four segments crowded on narrow screens and
  /// read as a control block rather than a field.
  Widget _statusRow() {
    final l = AppLocalizations.of(context)!;
    final current =
        widget.statusOptions.where((o) => o.$1 == _status).firstOrNull?.$2 ?? _status;
    return _propRow(
      label: l.kbStatus,
      value: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.circle, size: 10, color: todoStatusColor(context, _status)),
          const SizedBox(width: 6),
          Text(current),
        ],
      ),
      onTap: _pickStatus,
    );
  }

  /// One aligned property row (status/start/end): fixed label column,
  /// value, optional clear ✕, chevron — one structure and one 16px
  /// margin grid for all three rows (user feedback: the previous mix
  /// of full-width text buttons read scattered). Row height ≥44px.
  Widget _propRow({
    required String label,
    required Widget value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ),
            Expanded(child: Align(alignment: Alignment.centerLeft, child: value)),
            if (onClear != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: l.kbClear,
                onPressed: onClear,
                icon: Icon(LucideIcons.x, size: 16, color: theme.colorScheme.outline),
              ),
            Icon(LucideIcons.chevronRight, size: 16, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }

  /// Bottom-sheet single pick for the status row — full-width rows
  /// beat four cramped segments on a phone; same interaction as the
  /// date pickers (tap the row, pick, sheet closes).
  Future<void> _pickStatus() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final l = AppLocalizations.of(sheetContext)!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                child: Text(l.kbStatus, style: theme.textTheme.labelLarge),
              ),
              for (final (id, label) in widget.statusOptions)
                ListTile(
                  leading: Icon(LucideIcons.circle,
                      size: 10, color: todoStatusColor(sheetContext, id)),
                  title: Text(label),
                  trailing: id == _status
                      ? Icon(LucideIcons.check, size: 18, color: theme.colorScheme.primary)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(id),
                ),
            ],
          ),
        );
      },
    );
    if (picked == null || picked == _status || !mounted) return;
    setState(() {
      _status = picked;
      _dirty = true;
    });
  }

  /// One start/end datetime row: same aligned grid as the status row,
  /// picker on tap, clear ✕ when set.
  Widget _dateRow(bool isEnd) {
    final l = AppLocalizations.of(context)!;
    final value = isEnd ? _endDate : _date;
    final scheme = Theme.of(context).colorScheme;
    return _propRow(
      label: isEnd ? widget.endDateLabel! : widget.dateLabel!,
      value: Text(
        value == null ? l.kbNotSet : formatShortDate(value, withTime: true),
        style: value == null ? TextStyle(color: scheme.outline) : null,
      ),
      onTap: () => _pickDate(isEnd),
      onClear: value == null
          ? null
          : () => setState(() {
              if (isEnd) {
                _endDate = null;
              } else {
                _date = null;
              }
              _dirty = true;
            }),
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
              // Property block boundary before the content field.
              const Divider(height: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: MarkdownField(
                    controller: _text,
                    hint: widget.hint.isEmpty ? null : widget.hint,
                    autofocus: widget.initialText.isEmpty,
                    onChanged: (_) => setState(() => _dirty = true),
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
