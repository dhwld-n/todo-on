import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../data/korean_holidays.dart';
import '../models/category.dart';
import '../models/todo_item.dart';
import '../providers/providers.dart';

const int _kMaxChipsPerDay = 3;

// Diary-day markers - picked to read on both the light and dark themes.
const kMyDiaryColor = Color(0xFFF0A04B);
const kExchangeDiaryColor = Color(0xFF3DBFA8);

/// "내 일기" / "교환일기" book beside a day's number.
class _DiaryMark extends StatelessWidget {
  static const size = 10.0;

  final Color color;

  const _DiaryMark({super.key, required this.color});

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.menu_book_rounded, size: size, color: color);
}

class _DiaryLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _DiaryLegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.menu_book_rounded, size: 16, color: color),
      const SizedBox(width: 4),
      Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    ],
  );
}

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

class CalendarSidebar extends ConsumerWidget {
  final ScrollController? scrollController;

  /// Called whenever a day is tapped, after [selectedDateProvider] is set.
  /// Tapping the selected day again keeps it selected: clearing it showed
  /// every todo ever written.
  final ValueChanged<DateTime>? onDaySelected;

  const CalendarSidebar({super.key, this.scrollController, this.onDaySelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAsync = ref.watch(todosProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final focusedMonth = ref.watch(focusedMonthProvider);
    final todos = todosAsync.value ?? const [];
    final myDiaryDates =
        ref.watch(myDiaryDatesProvider).value ?? const <String>{};
    final exchangeDiaryDates = ref.watch(exchangeDiaryDatesProvider);
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
      final dateKey = dateKeyFor(day);

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
            // [내 일기][day][교환일기]: both slots always reserve their width
            // so the number stays centered, and a row can't overlap the way
            // corner-pinned marks did in a ~43px phone cell. scaleDown is
            // the backstop for anything narrower.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: _DiaryMark.size,
                    child: !isOutside && myDiaryDates.contains(dateKey)
                        ? _DiaryMark(
                            key: ValueKey('my-diary-$dateKey'),
                            color: kMyDiaryColor,
                          )
                        : null,
                  ),
                  const SizedBox(width: 2),
                  Text(
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
                  const SizedBox(width: 2),
                  SizedBox(
                    width: _DiaryMark.size,
                    child: !isOutside && exchangeDiaryDates.contains(dateKey)
                        ? _DiaryMark(
                            key: ValueKey('exchange-diary-$dateKey'),
                            color: kExchangeDiaryColor,
                          )
                        : null,
                  ),
                ],
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
              // The default also claims vertical swipes (to switch month/week
              // format, unused here), which ate touch scrolling on phones.
              availableGestures: AvailableGestures.horizontalSwipe,
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(fontWeight: FontWeight.bold),
                weekendStyle: TextStyle(fontWeight: FontWeight.bold),
              ),
              selectedDayPredicate: (day) =>
                  selectedDate != null && isSameDay(day, selectedDate),
              onDaySelected: (selectedDay, focusedDay) {
                ref.read(focusedMonthProvider.notifier).state = focusedDay;
                ref.read(selectedDateProvider.notifier).state = selectedDay;
                onDaySelected?.call(selectedDay);
              },
              onPageChanged: (focusedDay) {
                ref.read(focusedMonthProvider.notifier).state = focusedDay;
              },
              calendarFormat: CalendarFormat.month,
              // The header row centers the chevrons on the whole title +
              // legend block; the extra bottom padding lifts them back level
              // with the month title.
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                leftChevronPadding: EdgeInsets.fromLTRB(12, 12, 12, 36),
                rightChevronPadding: EdgeInsets.fromLTRB(12, 12, 12, 36),
              ),
              calendarBuilders: CalendarBuilders(
                // Title + diary legend right under it, where it's seen.
                // A custom title drops table_calendar's own tap handler, so
                // the year/month picker is wired back up here - on the title
                // only, the legend is just a label.
                headerTitleBuilder: (context, day) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _showYearMonthPicker(context, ref, day),
                      child: Text(
                        DateFormat.yMMMM('ko_KR').format(day),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'GriunCocochoitoon',
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        _DiaryLegendItem(color: kMyDiaryColor, label: '내 일기'),
                        _DiaryLegendItem(
                          color: kExchangeDiaryColor,
                          label: '교환일기',
                        ),
                      ],
                    ),
                  ],
                ),
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
