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

/// The 보관함 tab: take todos out onto a day picked then, or put some of
/// the calendar's selected day's todos in.
class ArchivePane extends ConsumerStatefulWidget {
  const ArchivePane({super.key});

  @override
  ConsumerState<ArchivePane> createState() => _ArchivePaneState();
}

class _ArchivePaneState extends ConsumerState<ArchivePane> {
  // Picking from the selected day's todos to put in, instead of from 보관함.
  var _puttingIn = false;
  final _picked = <String>{};
  var _busy = false;

  DateTime get _day =>
      ref.read(selectedDateProvider) ?? DateUtils.dateOnly(DateTime.now());

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
    final from = _day;
    final day = await showDatePicker(
      context: context,
      helpText: '어느 날 할까요?',
      initialDate: from,
      firstDate: DateTime(from.year - 5),
      lastDate: DateTime(from.year + 10),
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

  /// Which day's todos to put in; the calendar follows.
  Future<void> _pickDay() async {
    final from = _day;
    final day = await showDatePicker(
      context: context,
      initialDate: from,
      firstDate: DateTime(from.year - 5),
      lastDate: DateTime(from.year + 10),
    );
    if (day == null || !mounted) return;
    ref.read(selectedDateProvider.notifier).state = day;
    setState(_picked.clear);
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
    ref.watch(selectedDateProvider);
    final day = _day;
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
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: _puttingIn
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
                        child: Text(
                          '${DateFormat('M월 d일').format(day)} 할 일 넣기',
                          style: titleStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: _busy ? null : _pickDay,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        tooltip: '다른 날 고르기',
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: Text('보관함', style: titleStyle)),
                      TextButton.icon(
                        onPressed: _busy ? null : () => _switch(true),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('할 일 넣기'),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Text(
                      empty,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).disabledColor),
                    ),
                  )
                // Ink (the checked rows' tint) paints on the nearest
                // Material; the card around this pane is only a box.
                : Material(
                    type: MaterialType.transparency,
                    child: ListView(
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
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: _puttingIn
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
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: hasPicks ? _takeOut : null,
                      child: Text('꺼내기${_count()}'),
                    ),
                  ],
          ),
        ],
      ),
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
