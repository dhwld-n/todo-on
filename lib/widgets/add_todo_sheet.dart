import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/todo_item.dart';
import '../providers/providers.dart';
import '../services/reminder_service.dart';

Future<void> showAddEditTodoSheet(
  BuildContext context,
  WidgetRef ref, {
  TodoItem? existing,
  DateTime? initialDate,
  String? initialCategoryId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => AddEditTodoSheet(
      existing: existing,
      initialDate: initialDate,
      initialCategoryId: initialCategoryId,
    ),
  );
}

/// Deletes [todo] from its list. A repeating one asks first whether only
/// this day goes or this day and every one after it. Resolves to whether
/// anything was deleted.
Future<bool> deleteTodoAsking(
  BuildContext context,
  WidgetRef ref,
  TodoItem todo,
) async {
  final service = ref.read(firestoreServiceProvider);
  if (service == null) return false;
  if (!todo.isRepeating) {
    await service.deleteTodo(todo.id);
    return true;
  }
  final choice = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('반복하는 할 일이에요'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'day'),
          child: const Text('이 날만 삭제'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'after'),
          child: const Text('이 날부터 모두 삭제'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
      ],
    ),
  );
  switch (choice) {
    case 'day':
      await service.skipRepeatOn(todo.id, todo.dueDate!);
    case 'after':
      await service.endRepeatBefore(todo, todo.dueDate!);
    default:
      return false;
  }
  return true;
}

enum _Repeat { once, weekly, monthly }

const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

class AddEditTodoSheet extends ConsumerStatefulWidget {
  final TodoItem? existing;
  final DateTime? initialDate;
  final String? initialCategoryId;
  const AddEditTodoSheet({
    super.key,
    this.existing,
    this.initialDate,
    this.initialCategoryId,
  });

  @override
  ConsumerState<AddEditTodoSheet> createState() => _AddEditTodoSheetState();
}

class _AddEditTodoSheetState extends ConsumerState<AddEditTodoSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  String? _categoryId;
  late DateTime _dueDate;
  late bool _showNoteField;
  late bool _isPrivate;
  int? _remindMinutes;
  late _Repeat _repeat;
  late Set<int> _weekdays;
  late Set<int> _monthDays;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    _noteController = TextEditingController(text: widget.existing?.note ?? '');
    _categoryId = widget.existing?.categoryId ?? widget.initialCategoryId;
    _dueDate = widget.existing?.dueDate ?? widget.initialDate ?? DateTime.now();
    // Adding a new todo starts with just the title field; note can be
    // expanded on demand. Editing shows the note if one already exists.
    _showNoteField = widget.existing != null && widget.existing!.note != null;
    _isPrivate = widget.existing?.isPrivate ?? false;
    _remindMinutes = widget.existing?.remindMinutes;
    _weekdays = {...?widget.existing?.repeatWeekdays};
    _monthDays = {...?widget.existing?.repeatMonthDays};
    _repeat = _weekdays.isNotEmpty
        ? _Repeat.weekly
        : _monthDays.isNotEmpty
        ? _Repeat.monthly
        : _Repeat.once;
  }

  /// Switching to a repeat starts with the todo's own day picked, so one
  /// tap already makes a working repeat.
  void _setRepeat(_Repeat repeat) => setState(() {
    _repeat = repeat;
    if (repeat == _Repeat.weekly && _weekdays.isEmpty) {
      _weekdays.add(_dueDate.weekday);
    }
    if (repeat == _Repeat.monthly && _monthDays.isEmpty) {
      _monthDays.add(_dueDate.day);
    }
  });

  Future<void> _pickRemindTime() async {
    final current = _remindMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null || !mounted) return;
    setState(() => _remindMinutes = picked.hour * 60 + picked.minute);
    // Ask right away, while it's clear what the permission is for.
    askReminderPermission(context);
  }

  String _repeatSummary() {
    final start = DateFormat(
      'M월 d일',
    ).format(widget.existing?.seriesStart ?? _dueDate);
    if (_repeat == _Repeat.weekly) {
      if (_weekdays.isEmpty) return '요일을 골라주세요';
      final days = (_weekdays.toList()..sort())
          .map((d) => _weekdayNames[d - 1])
          .join(', ');
      return '$start부터 매주 $days요일에 알아서 떠요';
    }
    if (_monthDays.isEmpty) return '날짜를 골라주세요';
    final days = (_monthDays.toList()..sort()).join(', ');
    return '$start부터 매달 $days일에 알아서 떠요';
  }

  bool _categoryIsPrivate(List<TodoCategory> categories) =>
      _categoryId != null &&
      categories.any((c) => c.id == _categoryId && c.isPrivate);

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  bool _saving = false;

  /// One press, one item: the write takes a moment to reach the server,
  /// and presses in the meantime must not add copies.
  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _saveOnce();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveOnce() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final note = _noteController.text.trim();
    final service = ref.read(firestoreServiceProvider);
    if (service == null) return;

    final isPrivate = _categoryIsPrivate(
      ref.read(categoriesProvider).value ?? const <TodoCategory>[],
    );
    final weekdays = _repeat == _Repeat.weekly
        ? (_weekdays.toList()..sort())
        : <int>[];
    final monthDays = _repeat == _Repeat.monthly
        ? (_monthDays.toList()..sort())
        : <int>[];

    if (widget.existing == null) {
      final todo = TodoItem(
        id: const Uuid().v4(),
        title: title,
        categoryId: _categoryId,
        isDone: false,
        dueDate: _dueDate,
        createdAt: DateTime.now(),
        order: DateTime.now().millisecondsSinceEpoch,
        note: note.isEmpty ? null : note,
        categoryIsPrivate: isPrivate,
        isPrivate: _isPrivate,
        repeatWeekdays: weekdays,
        repeatMonthDays: monthDays,
        remindMinutes: _remindMinutes,
      );
      await service.addTodo(todo);
    } else {
      final updated = widget.existing!.copyWith(
        title: title,
        categoryId: _categoryId,
        clearCategory: _categoryId == null,
        dueDate: _dueDate,
        note: note.isEmpty ? null : note,
        clearNote: note.isEmpty,
        categoryIsPrivate: isPrivate,
        isPrivate: _isPrivate,
        repeatWeekdays: weekdays,
        repeatMonthDays: monthDays,
        remindMinutes: _remindMinutes,
        clearRemind: _remindMinutes == null,
        // Back to one day: it stays on the day it was opened from.
        clearSeriesStart: weekdays.isEmpty && monthDays.isEmpty,
      );
      await service.updateTodo(updated);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.existing == null ? '할 일 추가' : '할 일 수정',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (widget.existing != null)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    tooltip: '삭제',
                    onPressed: () async {
                      final deleted = await deleteTodoAsking(
                        context,
                        ref,
                        widget.existing!,
                      );
                      if (deleted && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '할 일',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            if (_showNoteField) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                autofocus: widget.existing == null,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '메모',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showNoteField = true),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('메모 추가'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SegmentedButton<_Repeat>(
              segments: const [
                ButtonSegment(value: _Repeat.once, label: Text('하루만')),
                ButtonSegment(value: _Repeat.weekly, label: Text('요일마다')),
                ButtonSegment(value: _Repeat.monthly, label: Text('매달 날짜')),
              ],
              selected: {_repeat},
              showSelectedIcon: false,
              onSelectionChanged: (s) => _setRepeat(s.single),
            ),
            if (_repeat != _Repeat.once) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (
                    var i = 1;
                    i <= (_repeat == _Repeat.weekly ? 7 : 31);
                    i++
                  )
                    _DayToggle(
                      label: _repeat == _Repeat.weekly
                          ? _weekdayNames[i - 1]
                          : '$i',
                      selected:
                          (_repeat == _Repeat.weekly ? _weekdays : _monthDays)
                              .contains(i),
                      onTap: () => setState(() {
                        final set = _repeat == _Repeat.weekly
                            ? _weekdays
                            : _monthDays;
                        if (!set.remove(i)) set.add(i);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _repeatSummary(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            // A repeat follows its days; only a one-day todo moves by date.
            if (widget.existing != null && _repeat == _Repeat.once) ...[
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final tomorrow = today.add(const Duration(days: 1));
                  final dueDay = DateTime(
                    _dueDate.year,
                    _dueDate.month,
                    _dueDate.day,
                  );
                  return Row(
                    children: [
                      ChoiceChip(
                        label: const Text('오늘 하기'),
                        selected: dueDay == today,
                        onSelected: (_) => setState(() => _dueDate = today),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('내일 하기'),
                        selected: dueDay == tomorrow,
                        onSelected: (_) => setState(() => _dueDate = tomorrow),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDueDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(DateFormat('yyyy년 M월 d일').format(_dueDate)),
              ),
            ],
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_none),
              title: const Text('알림'),
              subtitle: const Text('그 시간에 폰 잠금 화면과 알림창에 소리 없이 떠요'),
              onTap: _pickRemindTime,
              trailing: _remindMinutes == null
                  ? TextButton(
                      onPressed: _pickRemindTime,
                      child: const Text('시간 정하기'),
                    )
                  : InputChip(
                      label: Text(
                        TimeOfDay(
                          hour: _remindMinutes! ~/ 60,
                          minute: _remindMinutes! % 60,
                        ).format(context),
                      ),
                      onPressed: _pickRemindTime,
                      deleteButtonTooltipMessage: '알림 끄기',
                      onDeleted: () => setState(() => _remindMinutes = null),
                    ),
            ),
            Builder(
              builder: (context) {
                final inPrivateCategory = _categoryIsPrivate(
                  ref.watch(categoriesProvider).value ?? const [],
                );
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isPrivate || inPrivateCategory,
                  onChanged: inPrivateCategory
                      ? null
                      : (v) => setState(() => _isPrivate = v),
                  secondary: const Icon(Icons.lock_outline),
                  title: const Text('나만 보기'),
                  subtitle: Text(
                    inPrivateCategory
                        ? '비공개 카테고리라 이미 친구에게 안 보여요'
                        : '켜면 친구에게 이 할 일이 보이지 않아요',
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(widget.existing == null ? '추가' : '저장'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One round weekday or month-day button: seven fit on a phone's row.
class _DayToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DayToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? scheme.primary : null,
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(color: selected ? scheme.onPrimary : null),
          ),
        ),
      ),
    );
  }
}
