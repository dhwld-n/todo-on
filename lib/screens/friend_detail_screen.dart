import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../data/korean_holidays.dart';
import '../models/category.dart';
import '../models/todo_item.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/todo_tile.dart';
import 'friend_chat_screen.dart';

const double _kBreakpoint = 700;
const int _kMaxChipsPerDay = 3;

class FriendDetailScreen extends ConsumerStatefulWidget {
  final String uid;

  const FriendDetailScreen({super.key, required this.uid});

  @override
  ConsumerState<FriendDetailScreen> createState() =>
      _FriendDetailScreenState();
}

class _FriendDetailScreenState extends ConsumerState<FriendDetailScreen> {
  DateTime? _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();

  void _selectDay(DateTime day) {
    setState(() {
      _focusedMonth = day;
      _selectedDate = day;
    });
  }

  void _selectDayAndShowSheet(DateTime day) {
    setState(() {
      _focusedMonth = day;
      _selectedDate = day;
    });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).disabledColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) => _FriendTodoList(
                    todosAsync: ref.watch(friendTodosProvider(widget.uid)),
                    categoriesAsync: ref.watch(
                      friendCategoriesProvider(widget.uid),
                    ),
                    selectedDate: day,
                    scrollController: controller,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(friendProfileProvider(widget.uid));
    final profile = profileAsync.value;
    final nickname = (profile?['nickname'] as String?)?.trim();
    final displayText = (nickname != null && nickname.isNotEmpty)
        ? nickname
        : widget.uid.substring(0, 8);
    final bio = (profile?['bio'] as String?)?.trim();
    final photoBase64 = profile?['photoBase64'] as String?;

    final todosAsync = ref.watch(friendTodosProvider(widget.uid));
    final categoriesAsync = ref.watch(friendCategoriesProvider(widget.uid));

    return Scaffold(
      appBar: AppBar(
        title: Text(displayText),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: '채팅',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FriendChatScreen(uid: widget.uid),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final header = _FriendHeader(
              displayText: displayText,
              bio: bio,
              photoBase64: photoBase64,
            );
            final calendar = _FriendCalendar(
              todosAsync: todosAsync,
              categoriesAsync: categoriesAsync,
              selectedDate: _selectedDate,
              focusedMonth: _focusedMonth,
              onDaySelected: _selectDay,
              onPageChanged: (day) => setState(() => _focusedMonth = day),
            );
            final list = _FriendTodoList(
              todosAsync: todosAsync,
              categoriesAsync: categoriesAsync,
              selectedDate: _selectedDate,
            );

            if (constraints.maxWidth >= _kBreakpoint) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          header,
                          const SizedBox(height: 16),
                          _Card(child: calendar),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _Card(child: list)),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 16),
                Expanded(
                  child: _Card(
                    child: _FriendCalendar(
                      todosAsync: todosAsync,
                      categoriesAsync: categoriesAsync,
                      selectedDate: _selectedDate,
                      focusedMonth: _focusedMonth,
                      onDaySelected: _selectDayAndShowSheet,
                      onPageChanged: (day) =>
                          setState(() => _focusedMonth = day),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.14)
        : kCardBorderLight;
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Padding(padding: const EdgeInsets.all(12), child: child),
          ),
        ),
        // Painted on top: the ClipRRect child above shares the same bounds
        // and would otherwise cover a border drawn as part of its decoration.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: borderColor, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FriendHeader extends StatelessWidget {
  final String displayText;
  final String? bio;
  final String? photoBase64;

  const _FriendHeader({
    required this.displayText,
    required this.bio,
    required this.photoBase64,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Theme.of(context).colorScheme.primary,
          backgroundImage: photoBase64 != null
              ? MemoryImage(base64Decode(photoBase64!))
              : null,
          child: photoBase64 == null
              ? Text(
                  displayText.isNotEmpty ? displayText[0] : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayText,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (bio != null && bio!.isNotEmpty)
                Text(bio!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

void _showYearMonthPicker(
  BuildContext context,
  DateTime focusedDay,
  ValueChanged<DateTime> onPicked,
) {
  var picked = DateTime(focusedDay.year, focusedDay.month);
  showModalBottomSheet<void>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: SizedBox(
          height: 300,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('취소'),
                  ),
                  TextButton(
                    onPressed: () {
                      onPicked(picked);
                      Navigator.of(context).pop();
                    },
                    child: const Text('완료'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoTheme(
                  data: CupertinoTheme.of(context).copyWith(
                    textTheme: CupertinoTheme.of(context).textTheme.copyWith(
                      dateTimePickerTextStyle: CupertinoTheme.of(context)
                          .textTheme
                          .dateTimePickerTextStyle
                          .copyWith(fontFamily: 'OwnglyphParkDaHyun'),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.monthYear,
                    initialDateTime: picked,
                    minimumYear: 2020,
                    maximumYear: 2035,
                    onDateTimeChanged: (dt) =>
                        picked = DateTime(dt.year, dt.month),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _FriendCalendar extends StatelessWidget {
  final AsyncValue<List<TodoItem>> todosAsync;
  final AsyncValue<List<TodoCategory>> categoriesAsync;
  final DateTime? selectedDate;
  final DateTime focusedMonth;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onPageChanged;

  const _FriendCalendar({
    required this.todosAsync,
    required this.categoriesAsync,
    required this.selectedDate,
    required this.focusedMonth,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final todos = todosAsync.value ?? const <TodoItem>[];
    final categoriesById = {
      for (final c in categoriesAsync.value ?? const <TodoCategory>[])
        c.id: c,
    };

    final eventsByDay = <DateTime, List<TodoItem>>{};
    for (final todo in todos) {
      final due = todo.dueDate;
      if (due == null) continue;
      final key = DateTime(due.year, due.month, due.day);
      (eventsByDay[key] ??= []).add(todo);
    }

    Widget cellBuilder(
      BuildContext context,
      DateTime day, {
      bool isToday = false,
      bool isSelected = false,
      bool isOutside = false,
    }) {
      final key = DateTime(day.year, day.month, day.day);
      final events = eventsByDay[key] ?? const <TodoItem>[];
      final colorScheme = Theme.of(context).colorScheme;
      final holidayName = holidayNameFor(day);
      const holidayColor = Color(0xFFE24C4C);

      return Container(
        width: double.infinity,
        height: double.infinity,
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.14)
              : isToday
              ? colorScheme.primary.withValues(alpha: 0.06)
              : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isToday || isSelected || holidayName != null
                      ? FontWeight.w800
                      : FontWeight.w500,
                  color: isOutside
                      ? Theme.of(context).disabledColor
                      : holidayName != null
                      ? holidayColor
                      : isSelected
                      ? colorScheme.primary
                      : null,
                ),
              ),
            ),
            if (holidayName != null && !isOutside)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: holidayColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  holidayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: holidayColor,
                  ),
                ),
              ),
            const SizedBox(height: 2),
            for (final todo in events.take(_kMaxChipsPerDay))
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: todo.isDone
                      ? Color(
                          categoriesById[todo.categoryId]?.colorValue ??
                              0xFF9AA5B1,
                        )
                      : const Color(0xFFBDBDBD),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  todo.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 8.5, color: Colors.white),
                ),
              ),
            if (events.length > _kMaxChipsPerDay)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '+${events.length - _kMaxChipsPerDay}',
                  style: TextStyle(
                    fontSize: 8.5,
                    color: Theme.of(context).disabledColor,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return TableCalendar<void>(
      locale: 'ko_KR',
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2035, 12, 31),
      focusedDay: focusedMonth,
      rowHeight: 104,
      daysOfWeekHeight: 24,
      sixWeekMonthsEnforced: true,
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(fontWeight: FontWeight.bold),
        weekendStyle: TextStyle(fontWeight: FontWeight.bold),
      ),
      selectedDayPredicate: (day) =>
          selectedDate != null && isSameDay(day, selectedDate),
      onDaySelected: (selectedDay, focusedDay) => onDaySelected(selectedDay),
      onPageChanged: onPageChanged,
      onHeaderTapped: (focusedDay) =>
          _showYearMonthPicker(context, focusedDay, onPageChanged),
      calendarFormat: CalendarFormat.month,
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(fontFamily: 'GriunCocochoitoon', fontSize: 20),
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) => cellBuilder(context, day),
        todayBuilder: (context, day, focusedDay) =>
            cellBuilder(context, day, isToday: true),
        selectedBuilder: (context, day, focusedDay) =>
            cellBuilder(context, day, isSelected: true),
        outsideBuilder: (context, day, focusedDay) =>
            cellBuilder(context, day, isOutside: true),
      ),
    );
  }
}

class _FriendTodoList extends StatelessWidget {
  final AsyncValue<List<TodoItem>> todosAsync;
  final AsyncValue<List<TodoCategory>> categoriesAsync;
  final DateTime? selectedDate;
  final ScrollController? scrollController;

  const _FriendTodoList({
    required this.todosAsync,
    required this.categoriesAsync,
    required this.selectedDate,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (selectedDate != null)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.primaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.event,
                  size: 16,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('yyyy년 M월 d일').format(selectedDate!),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: todosAsync.when(
            data: (todos) => categoriesAsync.when(
              data: (categories) {
                final filtered = todos.where((t) {
                  if (selectedDate == null) return true;
                  return t.dueDate != null &&
                      isSameDay(t.dueDate!, selectedDate!);
                }).toList();

                final byCategory = <String?, List<TodoItem>>{};
                for (final t in filtered) {
                  (byCategory[t.categoryId] ??= []).add(t);
                }
                for (final list in byCategory.values) {
                  list.sort((a, b) => a.order.compareTo(b.order));
                }

                final sections = <_SectionData>[
                  for (final c in categories)
                    _SectionData(category: c, todos: byCategory[c.id] ?? const []),
                  if ((byCategory[null] ?? const []).isNotEmpty)
                    _SectionData(category: null, todos: byCategory[null]!),
                ];

                final nonEmptySections = [
                  for (final s in sections)
                    if (s.todos.isNotEmpty) s,
                ];

                if (nonEmptySections.isEmpty) {
                  return Center(
                    child: Text(
                      selectedDate == null ? '할 일이 없어요.' : '이 날엔 할 일이 없어요.',
                      style: TextStyle(color: Theme.of(context).disabledColor),
                    ),
                  );
                }

                if (nonEmptySections.length < 3) {
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      for (final section in nonEmptySections)
                        _ReadOnlyCategorySection(
                          category: section.category,
                          todos: section.todos,
                        ),
                    ],
                  );
                }
                // 3+ categories: lay them out as responsive columns instead of
                // one long stacked list, matching the home screen's own list.
                return LayoutBuilder(
                  builder: (context, constraints) {
                    const minColumnWidth = 300.0;
                    const gap = 12.0;
                    final columns = (constraints.maxWidth / minColumnWidth)
                        .floor()
                        .clamp(1, nonEmptySections.length);
                    final columnWidth =
                        (constraints.maxWidth - gap * (columns - 1)) /
                        columns;
                    return SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final section in nonEmptySections)
                            SizedBox(
                              width: columnWidth,
                              child: _ReadOnlyCategorySection(
                                category: section.category,
                                todos: section.todos,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
          ),
        ),
      ],
    );
  }
}

class _SectionData {
  final TodoCategory? category;
  final List<TodoItem> todos;

  const _SectionData({required this.category, required this.todos});
}

class _ReadOnlyCategorySection extends StatelessWidget {
  final TodoCategory? category;
  final List<TodoItem> todos;

  const _ReadOnlyCategorySection({required this.category, required this.todos});

  @override
  Widget build(BuildContext context) {
    final color = category != null ? Color(category!.colorValue) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color?.withValues(alpha: 0.14) ??
                Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              if (color != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  category?.name ?? '카테고리 없음',
                  style: const TextStyle(
                    fontFamily: 'OwnglyphParkDaHyun',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final todo in todos)
          TodoTile(todo: todo, category: category),
      ],
    );
  }
}
