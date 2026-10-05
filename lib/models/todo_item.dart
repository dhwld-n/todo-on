import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

String _dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

class TodoItem {
  final String id;
  final String title;
  final String? categoryId;
  final bool isDone;
  final DateTime? dueDate;
  final DateTime createdAt;
  final int order;
  final String? note;
  // Denormalized from the category's own isPrivate flag at write time, so
  // friend-visible queries can filter on the todo directly instead of
  // needing read access to the (possibly private) category document.
  final bool categoryIsPrivate;
  // Hidden from friends on its own, whatever its category. Stored folded
  // into `categoryIsPrivate` too, so the friend query and security rules
  // (and older app versions) need only that one field.
  final bool isPrivate;

  // A repeating todo is one document: it shows up on every matching day from
  // its dueDate on, without anyone writing a todo for that day. Weekdays are
  // DateTime.monday..sunday (1-7); month days are 1-31.
  final List<int> repeatWeekdays;
  final List<int> repeatMonthDays;
  // yyyy-MM-dd keys: the days it was checked off, the days removed one by
  // one, and the last day it shows up (null = keeps going).
  final List<String> doneDates;
  final List<String> skipDates;
  final DateTime? repeatEnd;
  // Set only on one day's copy made by [expandRepeats]: the series' own
  // dueDate, which is what gets written back.
  final DateTime? seriesStart;
  // A quiet notification on the todo's day (each day, for a repeat) at
  // this many minutes after midnight; null = none.
  final int? remindMinutes;

  const TodoItem({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.isDone,
    required this.dueDate,
    required this.createdAt,
    required this.order,
    this.note,
    this.categoryIsPrivate = false,
    this.isPrivate = false,
    this.repeatWeekdays = const [],
    this.repeatMonthDays = const [],
    this.doneDates = const [],
    this.skipDates = const [],
    this.repeatEnd,
    this.seriesStart,
    this.remindMinutes,
  });

  bool get isRepeating =>
      repeatWeekdays.isNotEmpty || repeatMonthDays.isNotEmpty;

  /// Whether the series has a day on [day] (ignoring its start and end).
  bool repeatsOn(DateTime day) =>
      repeatWeekdays.contains(day.weekday) || repeatMonthDays.contains(day.day);

  factory TodoItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final dueTimestamp = data['dueDate'] as Timestamp?;
    final createdTimestamp = data['createdAt'] as Timestamp?;
    List<T> list<T>(String key) => [
      for (final v in (data[key] as List?) ?? const [])
        if (v is T) v,
    ];
    return TodoItem(
      id: doc.id,
      title: data['title'] as String,
      categoryId: data['categoryId'] as String?,
      isDone: data['isDone'] as bool? ?? false,
      dueDate: dueTimestamp?.toDate(),
      createdAt: createdTimestamp?.toDate() ?? DateTime.now(),
      order: data['order'] as int? ?? 0,
      note: data['note'] as String?,
      categoryIsPrivate: data['categoryIsPrivate'] as bool? ?? false,
      isPrivate: data['isPrivate'] as bool? ?? false,
      repeatWeekdays: list<int>('repeatWeekdays'),
      repeatMonthDays: list<int>('repeatMonthDays'),
      doneDates: list<String>('doneDates'),
      skipDates: list<String>('skipDates'),
      repeatEnd: (data['repeatEnd'] as Timestamp?)?.toDate(),
      remindMinutes: data['remindMinutes'] as int?,
    );
  }

  Map<String, dynamic> toFirestore() {
    final due = seriesStart ?? dueDate;
    return {
      'title': title,
      'categoryId': categoryId,
      // A series has no single done state; each day's is in doneDates.
      'isDone': isRepeating ? false : isDone,
      'dueDate': due != null ? Timestamp.fromDate(due) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'order': order,
      'note': note,
      'categoryIsPrivate': categoryIsPrivate || isPrivate,
      'isPrivate': isPrivate,
      'repeatWeekdays': repeatWeekdays,
      'repeatMonthDays': repeatMonthDays,
      'doneDates': doneDates,
      'skipDates': skipDates,
      'repeatEnd': repeatEnd != null ? Timestamp.fromDate(repeatEnd!) : null,
      'remindMinutes': remindMinutes,
    };
  }

  TodoItem copyWith({
    String? title,
    String? categoryId,
    bool clearCategory = false,
    bool? isDone,
    DateTime? dueDate,
    bool clearDueDate = false,
    int? order,
    String? note,
    bool clearNote = false,
    bool? categoryIsPrivate,
    bool? isPrivate,
    List<int>? repeatWeekdays,
    List<int>? repeatMonthDays,
    bool clearSeriesStart = false,
    int? remindMinutes,
    bool clearRemind = false,
  }) {
    return TodoItem(
      id: id,
      title: title ?? this.title,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      isDone: isDone ?? this.isDone,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      createdAt: createdAt,
      order: order ?? this.order,
      note: clearNote ? null : (note ?? this.note),
      categoryIsPrivate: categoryIsPrivate ?? this.categoryIsPrivate,
      isPrivate: isPrivate ?? this.isPrivate,
      repeatWeekdays: repeatWeekdays ?? this.repeatWeekdays,
      repeatMonthDays: repeatMonthDays ?? this.repeatMonthDays,
      doneDates: doneDates,
      skipDates: skipDates,
      repeatEnd: repeatEnd,
      seriesStart: clearSeriesStart ? null : seriesStart,
      remindMinutes: clearRemind ? null : (remindMinutes ?? this.remindMinutes),
    );
  }
}

/// [todos] with every repeating one replaced by a copy for each day it
/// shows up on, so date filters, calendars and stats treat those copies
/// like ordinary todos. Copies keep the series' id.
// ponytail: expands up to a year past today; a calendar paged further ahead
// shows no repeats there. Widen [until] if anyone plans that far.
List<TodoItem> expandRepeats(List<TodoItem> todos, {DateTime? until}) {
  final today = _day(DateTime.now());
  final last = _day(until ?? today.add(const Duration(days: 366)));
  final out = <TodoItem>[];
  for (final t in todos) {
    final start = t.dueDate;
    if (!t.isRepeating || start == null) {
      out.add(t);
      continue;
    }
    final end = t.repeatEnd != null && t.repeatEnd!.isBefore(last)
        ? _day(t.repeatEnd!)
        : last;
    // Calendar days, not 24h steps, so DST shifts can't skip or repeat one.
    for (
      var d = _day(start);
      !d.isAfter(end);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      if (!t.repeatsOn(d)) continue;
      final key = _dayKey(d);
      if (t.skipDates.contains(key)) continue;
      out.add(
        TodoItem(
          id: t.id,
          title: t.title,
          categoryId: t.categoryId,
          isDone: t.doneDates.contains(key),
          dueDate: d,
          createdAt: t.createdAt,
          order: t.order,
          note: t.note,
          categoryIsPrivate: t.categoryIsPrivate,
          isPrivate: t.isPrivate,
          repeatWeekdays: t.repeatWeekdays,
          repeatMonthDays: t.repeatMonthDays,
          doneDates: t.doneDates,
          skipDates: t.skipDates,
          repeatEnd: t.repeatEnd,
          seriesStart: start,
          remindMinutes: t.remindMinutes,
        ),
      );
    }
  }
  return out;
}
