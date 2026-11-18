import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/todo_item.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import 'paper.dart';
import 'todo_selection.dart';

/// One todo found by a search, with the day to go to (null: in 보관함).
/// A repeating todo is found once, at its next day (or its last, when
/// they're all past) rather than once per day.
class TodoSearchHit {
  final TodoItem todo;
  final DateTime? day;

  const TodoSearchHit(this.todo, this.day);
}

/// The todos whose title or memo contains [query] (any case), nearest
/// [today] first; 보관함 ones last.
List<TodoSearchHit> searchTodos(
  List<TodoItem> todos,
  String query,
  DateTime today,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  today = DateTime(today.year, today.month, today.day);
  bool matches(TodoItem t) =>
      t.title.toLowerCase().contains(q) ||
      (t.note?.toLowerCase().contains(q) ?? false);

  final hits = <TodoSearchHit>[];
  // A series' copies share its id: keep the one to show.
  final series = <String, TodoItem>{};
  for (final t in todos) {
    if (!matches(t)) continue;
    if (!t.isRepeating) {
      hits.add(TodoSearchHit(t, t.dueDate));
      continue;
    }
    final kept = series[t.id];
    final day = t.dueDate!;
    if (kept == null) {
      series[t.id] = t;
      continue;
    }
    final keptDay = kept.dueDate!;
    final keptAhead = !keptDay.isBefore(today);
    final ahead = !day.isBefore(today);
    // The next day from today on; failing that, the latest one.
    if (ahead && (!keptAhead || day.isBefore(keptDay)) ||
        !ahead && !keptAhead && day.isAfter(keptDay)) {
      series[t.id] = t;
    }
  }
  hits.addAll([for (final t in series.values) TodoSearchHit(t, t.dueDate)]);
  int distance(TodoSearchHit h) => h.day == null
      ? 1 << 30
      : DateTime(
          h.day!.year,
          h.day!.month,
          h.day!.day,
        ).difference(today).inDays.abs();
  hits.sort((a, b) {
    final byDistance = distance(a).compareTo(distance(b));
    if (byDistance != 0) return byDistance;
    // Same distance either side: the one ahead first.
    return (b.day ?? today).compareTo(a.day ?? today);
  });
  return hits;
}

/// Opens the todo search; picking a result goes to its day.
Future<void> showTodoSearch(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: const FractionallySizedBox(
      heightFactor: 0.85,
      child: _TodoSearchSheet(),
    ),
  ),
);

class _TodoSearchSheet extends ConsumerStatefulWidget {
  const _TodoSearchSheet();

  @override
  ConsumerState<_TodoSearchSheet> createState() => _TodoSearchSheetState();
}

class _TodoSearchSheetState extends ConsumerState<_TodoSearchSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _go(TodoSearchHit hit) {
    final day = hit.day;
    ref.read(selectedTodoIdsProvider.notifier).state = const {};
    if (day == null) {
      ref.read(contentModeProvider.notifier).state = ContentMode.archive;
    } else {
      final d = DateTime(day.year, day.month, day.day);
      ref.read(selectedDateProvider.notifier).state = d;
      ref.read(focusedMonthProvider.notifier).state = d;
      ref.read(contentModeProvider.notifier).state = ContentMode.todo;
      // On a phone, show the day's list rather than the calendar.
      ref.read(mobileCalendarExpandedProvider.notifier).state = false;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(todosProvider).value ?? const <TodoItem>[];
    final categories = {
      for (final c in ref.watch(categoriesProvider).value ?? <TodoCategory>[])
        c.id: c,
    };
    return ValueListenableBuilder(
      valueListenable: _query,
      builder: (context, value, _) {
        final query = value.text.trim();
        final hits = searchTodos(todos, query, DateTime.now());
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Highlighted(
                  color: Diary.marker(context),
                  child: Text(
                    '할 일 찾기',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {
                  if (hits.isNotEmpty) _go(hits.first);
                },
                decoration: const InputDecoration(
                  hintText: '할 일 제목이나 메모',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: query.isEmpty
                    ? _Hint('찾을 말을 쓰면 그 할 일이 있는 날이 나와요')
                    : hits.isEmpty
                    ? _Hint("'$query' 할 일이 없어요")
                    : ListView.builder(
                        itemCount: hits.length,
                        itemBuilder: (context, i) => _HitRow(
                          hit: hits[i],
                          category: categories[hits[i].todo.categoryId],
                          onTap: () => _go(hits[i]),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;

  const _Hint(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: Diary.muted(context)),
    ),
  );
}

/// A found todo: its day (highlighted) over its title and category; a line
/// in the notebook like the day's list.
class _HitRow extends StatelessWidget {
  final TodoSearchHit hit;
  final TodoCategory? category;
  final VoidCallback onTap;

  const _HitRow({
    required this.hit,
    required this.category,
    required this.onTap,
  });

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final pattern = day.year == now.year ? 'M월 d일 (E)' : 'yyyy년 M월 d일 (E)';
    return DateFormat(pattern, 'ko_KR').format(day);
  }

  @override
  Widget build(BuildContext context) {
    final todo = hit.todo;
    final day = hit.day;
    final color = category != null
        ? Color(category!.colorValue)
        : Theme.of(context).disabledColor;
    final muted = Diary.muted(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Highlighted(
                            color: Diary.highlight(context, kAccentBlue),
                            child: Text(
                              day == null ? '보관함' : _dayLabel(day),
                              style: const TextStyle(
                                fontFamily: 'OwnglyphParkDaHyun',
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (todo.isRepeating) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.repeat, size: 14, color: muted),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        todo.title,
                        style: TextStyle(
                          fontSize: 15,
                          color: todo.isDone ? muted : null,
                          decoration: todo.isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            category?.name ?? '카테고리 없음',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: muted),
              ],
            ),
          ),
        ),
        const DashedRule(),
      ],
    );
  }
}
