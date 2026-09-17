import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/providers.dart';
import '../utils/activity_stats.dart';

enum _HeatmapView { week, month, year }

const _kWeekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

class ActivityHeatmap extends ConsumerStatefulWidget {
  const ActivityHeatmap({super.key});

  @override
  ConsumerState<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends ConsumerState<ActivityHeatmap> {
  _HeatmapView _view = _HeatmapView.year;
  DateTime _anchor = DateTime.now();

  DateTime _startOfWeek(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));

  void _step(int direction) {
    setState(() {
      switch (_view) {
        case _HeatmapView.week:
          _anchor = _anchor.add(Duration(days: 7 * direction));
        case _HeatmapView.month:
          _anchor = DateTime(_anchor.year, _anchor.month + direction, 1);
        case _HeatmapView.year:
          _anchor = DateTime(_anchor.year + direction, _anchor.month);
      }
    });
  }

  String get _headerLabel {
    switch (_view) {
      case _HeatmapView.week:
        final start = _startOfWeek(_anchor);
        final end = start.add(const Duration(days: 6));
        return '${DateFormat('M/d').format(start)} - ${DateFormat('M/d').format(end)}';
      case _HeatmapView.month:
        return DateFormat('yyyy년 M월').format(_anchor);
      case _HeatmapView.year:
        return '${_anchor.year}';
    }
  }

  Color _levelColor(BuildContext context, int level) {
    final primary = Theme.of(context).colorScheme.primary;
    switch (level) {
      case 0:
        return Theme.of(context).colorScheme.surfaceContainerHighest;
      case 1:
        return primary.withValues(alpha: 0.28);
      case 2:
        return primary.withValues(alpha: 0.5);
      case 3:
        return primary.withValues(alpha: 0.72);
      default:
        return primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final todosAsync = ref.watch(todosProvider);
    final logsAsync = ref.watch(habitLogsProvider);

    return todosAsync.when(
      data: (todos) => logsAsync.when(
        data: (logs) {
          final counts = activityCountsByDate(todos, logs);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    '활동 지도',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: 'OwnglyphParkDaHyun',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  _ViewToggle(
                    view: _view,
                    onChanged: (v) => setState(() => _view = v),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _step(-1),
                  ),
                  Text(
                    _headerLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _step(1),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              switch (_view) {
                _HeatmapView.year => _YearGrid(
                  year: _anchor.year,
                  counts: counts,
                  levelColor: _levelColor,
                ),
                _HeatmapView.month => _MonthGrid(
                  month: _anchor,
                  counts: counts,
                  levelColor: _levelColor,
                ),
                _HeatmapView.week => _WeekRow(
                  start: _startOfWeek(_anchor),
                  counts: counts,
                  levelColor: _levelColor,
                ),
              },
              const SizedBox(height: 10),
              _Legend(levelColor: _levelColor),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('오류: $e'),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('오류: $e'),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final _HeatmapView view;
  final ValueChanged<_HeatmapView> onChanged;

  const _ViewToggle({required this.view, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget button(String label, _HeatmapView v) {
      final selected = v == view;
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onChanged(v),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            button('주', _HeatmapView.week),
            button('월', _HeatmapView.month),
            button('년', _HeatmapView.year),
          ],
        ),
      ),
    );
  }
}

typedef _LevelColorFn = Color Function(BuildContext context, int level);

class _YearGrid extends StatelessWidget {
  final int year;
  final Map<String, int> counts;
  final _LevelColorFn levelColor;

  const _YearGrid({
    required this.year,
    required this.counts,
    required this.levelColor,
  });

  @override
  Widget build(BuildContext context) {
    const cellSize = 12.0;
    const cellMargin = 1.5;
    const step = cellSize + cellMargin * 2;

    final jan1 = DateTime(year, 1, 1);
    final dec31 = DateTime(year, 12, 31);
    final firstMonday = jan1.subtract(
      Duration(days: (jan1.weekday - DateTime.monday) % 7),
    );
    final totalDays = dec31.difference(firstMonday).inDays + 1;
    final weeks = (totalDays / 7).ceil();

    Widget cell(DateTime date) {
      if (date.year != year) {
        return SizedBox(width: step, height: step);
      }
      final key = dateKeyFor(date);
      final count = counts[key] ?? 0;
      return Tooltip(
        message: '${DateFormat('M/d').format(date)} · $count개',
        child: Container(
          width: cellSize,
          height: cellSize,
          margin: const EdgeInsets.all(cellMargin),
          decoration: BoxDecoration(
            color: levelColor(context, activityLevel(count)),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      );
    }

    int? lastLabeledMonth;
    final monthLabels = <Widget>[];
    final weekColumns = <Widget>[];
    for (var w = 0; w < weeks; w++) {
      String? label;
      for (var d = 0; d < 7; d++) {
        final date = firstMonday.add(Duration(days: w * 7 + d));
        if (date.year == year && date.day == 1 && lastLabeledMonth != date.month) {
          label = DateFormat('M월').format(date);
          lastLabeledMonth = date.month;
        }
      }
      monthLabels.add(
        SizedBox(
          width: step,
          child: Text(
            label ?? '',
            style: TextStyle(
              fontSize: 9,
              color: Theme.of(context).disabledColor,
            ),
          ),
        ),
      );
      weekColumns.add(
        Column(
          children: [
            for (var d = 0; d < 7; d++)
              cell(firstMonday.add(Duration(days: w * 7 + d))),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Column(
              children: [
                const SizedBox(height: 14),
                for (final label in _kWeekdayLabels)
                  SizedBox(
                    height: step,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        color: Theme.of(context).disabledColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: monthLabels),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: weekColumns),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final Map<String, int> counts;
  final _LevelColorFn levelColor;

  const _MonthGrid({
    required this.month,
    required this.counts,
    required this.levelColor,
  });

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final firstCell = firstOfMonth.subtract(
      Duration(days: (firstOfMonth.weekday - DateTime.monday) % 7),
    );
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lastOfMonth = DateTime(month.year, month.month, daysInMonth);
    final totalCells =
        ((lastOfMonth.difference(firstCell).inDays + 1) / 7).ceil() * 7;

    return Column(
      children: [
        Row(
          children: [
            for (final label in _kWeekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).disabledColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < totalCells / 7; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Builder(
                  builder: (context) {
                    final date = firstCell.add(
                      Duration(days: row * 7 + col),
                    );
                    final inMonth = date.month == month.month;
                    final key = dateKeyFor(date);
                    final count = counts[key] ?? 0;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Tooltip(
                          message: '${DateFormat('M/d').format(date)} · $count개',
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: inMonth
                                    ? levelColor(context, activityLevel(count))
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: !inMonth
                                        ? Colors.transparent
                                        : activityLevel(count) >= 3
                                        ? Colors.white
                                        : Theme.of(context).textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }
}

class _WeekRow extends StatelessWidget {
  final DateTime start;
  final Map<String, int> counts;
  final _LevelColorFn levelColor;

  const _WeekRow({
    required this.start,
    required this.counts,
    required this.levelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Builder(
            builder: (context) {
              final date = start.add(Duration(days: i));
              final key = dateKeyFor(date);
              final count = counts[key] ?? 0;
              final level = activityLevel(count);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    children: [
                      Text(
                        _kWeekdayLabels[i],
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).disabledColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AspectRatio(
                        aspectRatio: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: levelColor(context, level),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '${date.day}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: level >= 3
                                    ? Colors.white
                                    : Theme.of(context).textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$count개',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).disabledColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final _LevelColorFn levelColor;

  const _Legend({required this.levelColor});

  @override
  Widget build(BuildContext context) {
    const labels = ['0', '1-2', '3-4', '5-6', '7+'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: levelColor(context, i),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 9,
                    color: Theme.of(context).disabledColor,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
