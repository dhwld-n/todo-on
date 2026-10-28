import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/todo_item.dart';
import '../providers/providers.dart';

/// Todos in 보관함: no day of their own. Repeats always have one (their
/// start), so they never land here.
List<TodoItem> archivedTodos(List<TodoItem> todos) => [
  for (final t in todos)
    if (t.dueDate == null && !t.isRepeating) t,
];

/// 보관함, opened from [day]: take todos out onto a day picked then, or put
/// some of [day]'s todos in.
Future<void> showArchiveDialog(BuildContext context, DateTime day) =>
    showDialog<void>(
      context: context,
      builder: (_) => ArchiveDialog(day: day),
    );

class ArchiveDialog extends ConsumerStatefulWidget {
  final DateTime day;

  const ArchiveDialog({super.key, required this.day});

  @override
  ConsumerState<ArchiveDialog> createState() => _ArchiveDialogState();
}

class _ArchiveDialogState extends ConsumerState<ArchiveDialog> {
  // Picking from [day]'s todos to put in, instead of from 보관함.
  var _puttingIn = false;
  final _picked = <String>{};
  var _busy = false;

  void _switch(bool puttingIn) => setState(() {
    _puttingIn = puttingIn;
    _picked.clear();
  });

  Future<void> _run(Future<void>? Function() write, String done) async {
    setState(() => _busy = true);
    try {
      await write();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      setState(_picked.clear);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('저장하지 못했어요')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _takeOut() async {
    final day = await showDatePicker(
      context: context,
      helpText: '어느 날 할까요?',
      initialDate: widget.day,
      firstDate: DateTime(widget.day.year - 5),
      lastDate: DateTime(widget.day.year + 10),
    );
    if (day == null || !mounted) return;
    final ids = [..._picked];
    await _run(
      () => ref.read(firestoreServiceProvider)?.unarchiveTodos(ids, day),
      '${DateFormat('M월 d일').format(day)}로 ${ids.length}개 꺼냈어요',
    );
  }

  Future<void> _delete() async {
    final ids = [..._picked];
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text('보관함에서 ${ids.length}개를 지울까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => ref.read(firestoreServiceProvider)?.deleteTodos(ids),
      '${ids.length}개를 지웠어요',
    );
  }

  Future<void> _putIn() async {
    final ids = [..._picked];
    await _run(
      () => ref.read(firestoreServiceProvider)?.archiveTodos(ids),
      '보관함에 ${ids.length}개 넣었어요',
    );
    if (mounted) _switch(false);
  }

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(todosProvider).value ?? const <TodoItem>[];
    final categories =
        ref.watch(categoriesProvider).value ?? const <TodoCategory>[];
    final day = widget.day;
    final shown = _puttingIn
        ? [
            for (final t in todos)
              if (!t.isRepeating &&
                  t.dueDate != null &&
                  DateUtils.isSameDay(t.dueDate, day))
                t,
          ]
        : archivedTodos(todos);
    final empty = _puttingIn
        ? '이 날은 보관함에 넣을 할 일이 없어요.\n(반복하는 할 일은 넣을 수 없어요)'
        : '보관함이 비어 있어요.\n위의 "할 일 넣기"로 넣어보세요.';
    final hasPicks = _picked.isNotEmpty && !_busy;

    return AlertDialog(
      title: _puttingIn
          ? Row(
              children: [
                IconButton(
                  onPressed: _busy ? null : () => _switch(false),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: '보관함으로 돌아가기',
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('${DateFormat('M월 d일').format(day)} 할 일 넣기'),
                ),
              ],
            )
          : Row(
              children: [
                const Expanded(child: Text('보관함')),
                TextButton.icon(
                  onPressed: _busy ? null : () => _switch(true),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('할 일 넣기'),
                ),
              ],
            ),
      content: SizedBox(
        width: 420,
        child: shown.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  empty,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).disabledColor),
                ),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final t in shown)
                    CheckboxListTile(
                      value: _picked.contains(t.id),
                      onChanged: _busy
                          ? null
                          : (on) => setState(
                              () => on == true
                                  ? _picked.add(t.id)
                                  : _picked.remove(t.id),
                            ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: Text(t.title),
                      subtitle: _categoryName(categories, t.categoryId),
                    ),
                ],
              ),
      ),
      actions: _puttingIn
          ? [
              FilledButton(
                onPressed: hasPicks ? _putIn : null,
                child: Text('보관함에 넣기${_count()}'),
              ),
            ]
          : [
              TextButton(
                onPressed: hasPicks ? _delete : null,
                child: const Text('지우기'),
              ),
              FilledButton(
                onPressed: hasPicks ? _takeOut : null,
                child: Text('꺼내기${_count()}'),
              ),
            ],
    );
  }

  String _count() => _picked.isEmpty ? '' : ' (${_picked.length})';

  static Widget? _categoryName(List<TodoCategory> all, String? id) {
    for (final c in all) {
      if (c.id == id) {
        return Text(c.name, style: TextStyle(color: Color(c.colorValue)));
      }
    }
    return null;
  }
}
