import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../utils/activity_stats.dart';
import 'manage_habits_sheet.dart';

class TodaysHabits extends ConsumerWidget {
  const TodaysHabits({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsProvider);
    final logsAsync = ref.watch(habitLogsProvider);
    final todayKey = dateKeyFor(DateTime.now());

    return habitsAsync.when(
      data: (habits) => logsAsync.when(
        data: (logs) {
          final logsByHabit = <String, Set<String>>{};
          for (final log in logs) {
            (logsByHabit[log.habitId] ??= {}).add(log.dateKey);
          }
          final doneToday = habits
              .where((h) => (logsByHabit[h.id] ?? const {}).contains(todayKey))
              .length;
          final allDone = habits.isNotEmpty && doneToday == habits.length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    '오늘의 습관',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: 'OwnglyphParkDaHyun',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (habits.isNotEmpty)
                    Text(
                      allDone ? '모두 완료! $doneToday/${habits.length}' : '$doneToday/${habits.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: allDone
                            ? Colors.green
                            : Theme.of(context).disabledColor,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (habits.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '아직 습관이 없어요. 아래 습관 관리에서 추가해보세요.',
                    style: TextStyle(color: Theme.of(context).disabledColor),
                  ),
                )
              else
                for (final habit in habits)
                  _HabitRow(
                    habitId: habit.id,
                    emoji: habit.emoji,
                    name: habit.name,
                    subtitle: habit.subtitle,
                    color: Color(habit.colorValue),
                    done: (logsByHabit[habit.id] ?? const {}).contains(
                      todayKey,
                    ),
                    streak: currentStreakFor(
                      habit.id,
                      logsByHabit[habit.id] ?? const {},
                    ),
                    onToggle: (v) => ref
                        .read(firestoreServiceProvider)
                        ?.setHabitLog(
                          habitId: habit.id,
                          dateKey: todayKey,
                          completed: v,
                        ),
                  ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => showManageHabitsSheet(context),
                  child: const Text('습관 관리'),
                ),
              ),
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

class _HabitRow extends StatelessWidget {
  final String habitId;
  final String emoji;
  final String name;
  final String? subtitle;
  final Color color;
  final bool done;
  final int streak;
  final ValueChanged<bool> onToggle;

  const _HabitRow({
    required this.habitId,
    required this.emoji,
    required this.name,
    required this.subtitle,
    required this.color,
    required this.done,
    required this.streak,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = Theme.of(context).disabledColor;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onToggle(!done),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: TextStyle(
                    color: done
                        ? disabled
                        : Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  children: [
                    TextSpan(
                      text: name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (subtitle != null) ...[
                      const TextSpan(text: ' · '),
                      TextSpan(text: subtitle),
                    ],
                  ],
                ),
              ),
            ),
            if (streak > 0) ...[
              const Icon(
                Icons.local_fire_department,
                size: 16,
                color: Colors.deepOrange,
              ),
              const SizedBox(width: 2),
              Text(
                '$streak',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepOrange,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
