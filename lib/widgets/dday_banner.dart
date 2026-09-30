import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/dday.dart';

import '../providers/providers.dart';

String _ddayLabel(DateTime target) {
  final today = DateTime.now();
  final diff = DateTime(
    target.year,
    target.month,
    target.day,
  ).difference(DateTime(today.year, today.month, today.day)).inDays;
  if (diff == 0) return 'D-Day';
  return diff > 0 ? 'D-$diff' : 'D+${-diff}';
}

class DdayBanner extends ConsumerWidget {
  const DdayBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ddays = Dday.listFrom(ref.watch(profileDocProvider).value);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final dday in ddays)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _DdayTile(
                dday: dday,
                onTap: () => _showEditDialog(context, ref, ddays, dday),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _showEditDialog(context, ref, ddays, null),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('디데이 추가'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DdayTile extends StatelessWidget {
  final Dday dday;
  final VoidCallback onTap;

  const _DdayTile({required this.dday, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              Icons.flag_outlined,
              size: 18,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dday.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            Text(
              _ddayLabel(dday.date),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Adds a D-day ([existing] null) or edits/deletes [existing], then saves
/// the whole list back.
void _showEditDialog(
  BuildContext context,
  WidgetRef ref,
  List<Dday> all,
  Dday? existing,
) {
  void save(List<Dday> next) =>
      ref.read(firestoreServiceProvider)?.saveDdays(next);
  showDialog<void>(
    context: context,
    builder: (_) => _EditDdayDialog(
      initialLabel: existing?.label,
      initialDate: existing?.date,
      onSave: (label, date) => save(
        existing == null
            ? [...all, Dday(id: const Uuid().v4(), label: label, date: date)]
            : [
                for (final d in all)
                  d.id == existing.id
                      ? Dday(id: d.id, label: label, date: date)
                      : d,
              ],
      ),
      onDelete: existing == null
          ? null
          : () => save([
              for (final d in all)
                if (d.id != existing.id) d,
            ]),
    ),
  );
}

class _EditDdayDialog extends ConsumerStatefulWidget {
  final String? initialLabel;
  final DateTime? initialDate;
  final void Function(String label, DateTime date) onSave;
  final VoidCallback? onDelete;

  const _EditDdayDialog({
    this.initialLabel,
    this.initialDate,
    required this.onSave,
    this.onDelete,
  });

  @override
  ConsumerState<_EditDdayDialog> createState() => _EditDdayDialogState();
}

class _EditDdayDialogState extends ConsumerState<_EditDdayDialog> {
  late final TextEditingController _labelController;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.initialLabel ?? '');
    _date = widget.initialDate;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final label = _labelController.text.trim();
    final canSave = label.isNotEmpty && _date != null;
    return AlertDialog(
      title: const Text('디데이 설정'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(labelText: '이름 (예: 수능)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(
              _date == null
                  ? '날짜 선택'
                  : '${_date!.year}.${_date!.month}.${_date!.day}',
            ),
          ),
        ],
      ),
      actions: [
        if (widget.onDelete != null)
          TextButton(
            onPressed: () {
              widget.onDelete!();
              Navigator.of(context).pop();
            },
            child: const Text('삭제'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: !canSave
              ? null
              : () {
                  widget.onSave(label, _date!);
                  Navigator.of(context).pop();
                },
          child: const Text('저장'),
        ),
      ],
    );
  }
}
