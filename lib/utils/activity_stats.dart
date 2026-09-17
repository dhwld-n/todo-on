import '../models/habit_log.dart';
import '../models/todo_item.dart';
import '../providers/providers.dart';

/// Counts completed todos (by due date) and habit completions per day.
Map<String, int> activityCountsByDate(
  List<TodoItem> todos,
  List<HabitLog> logs,
) {
  final counts = <String, int>{};
  for (final todo in todos) {
    if (!todo.isDone || todo.dueDate == null) continue;
    final key = dateKeyFor(todo.dueDate!);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  for (final log in logs) {
    counts[log.dateKey] = (counts[log.dateKey] ?? 0) + 1;
  }
  return counts;
}

/// Bucket 0..4 for a day's activity count, matching the heatmap legend
/// (0 / 1-2 / 3-4 / 5-6 / 7+).
int activityLevel(int count) {
  if (count <= 0) return 0;
  if (count <= 2) return 1;
  if (count <= 4) return 2;
  if (count <= 6) return 3;
  return 4;
}

/// Current streak (consecutive days including today) for a single habit.
int currentStreakFor(String habitId, Set<String> completedDateKeys) {
  var streak = 0;
  var day = DateTime.now();
  while (true) {
    final key = dateKeyFor(day);
    if (!completedDateKeys.contains(key)) break;
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}
