import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../data/korean_holidays.dart';
import '../models/category.dart';
import '../models/todo_item.dart';
import '../providers/providers.dart';

const int _kMaxChipsPerDay = 3;

void _showYearMonthPicker(
  BuildContext context,
  WidgetRef ref,
  DateTime focusedDay,
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
                      ref.read(focusedMonthProvider.notifier).state = picked;
                      Navigator.of(context).pop();
                    },
                    child: const Text('완료'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.monthYear,
                  initialDateTime: picked,
                  minimumYear: 2020,
                  maximumYear: 2035,
                  onDateTimeChanged: (dt) =>
                      picked = DateTime(dt.year, dt.month),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class CalendarSidebar extends ConsumerWidget {
  final bool embeddedInSheet;
  final ScrollController? scrollController;

  const CalendarSidebar({
    super.key,
    this.embeddedInSheet = false,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAsync = ref.watch(todosProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final focusedMonth = ref.watch(focusedMonthProvider);
    final todos = todosAsync.value ?? const [];
    final categoriesById = {
      for (final c in categoriesAsync.value ?? const <TodoCategory>[]) c.id: c,
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

    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        controller: scrollController,
        child: Column(
          children: [
            TableCalendar<void>(
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
              onDaySelected: (selectedDay, focusedDay) {
                ref.read(focusedMonthProvider.notifier).state = focusedDay;
                final current = ref.read(selectedDateProvider);
                if (current != null && isSameDay(current, selectedDay)) {
                  ref.read(selectedDateProvider.notifier).state = null;
                } else {
                  ref.read(selectedDateProvider.notifier).state = selectedDay;
                }
              },
              onPageChanged: (focusedDay) {
                ref.read(focusedMonthProvider.notifier).state = focusedDay;
              },
              onHeaderTapped: (focusedDay) =>
                  _showYearMonthPicker(context, ref, focusedDay),
              calendarFormat: CalendarFormat.month,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontFamily: 'GriunCocochoitoon',
                  fontSize: 20,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) =>
                    cellBuilder(context, day),
                todayBuilder: (context, day, focusedDay) =>
                    cellBuilder(context, day, isToday: true),
                selectedBuilder: (context, day, focusedDay) =>
                    cellBuilder(context, day, isSelected: true),
                outsideBuilder: (context, day, focusedDay) =>
                    cellBuilder(context, day, isOutside: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
