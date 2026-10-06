import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_on/models/todo_item.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/services/firestore_service.dart';
import 'package:todo_on/widgets/add_todo_sheet.dart';

TodoItem _series({
  List<int> weekdays = const [],
  List<int> monthDays = const [],
  List<String> done = const [],
  List<String> skip = const [],
  DateTime? end,
}) => TodoItem(
  id: 'gym',
  title: '헬스',
  categoryId: null,
  isDone: false,
  // A Monday, with a time of day like DateTime.now() leaves.
  dueDate: DateTime(2026, 10, 5, 14, 30),
  createdAt: DateTime(2026, 10, 5),
  order: 0,
  repeatWeekdays: weekdays,
  repeatMonthDays: monthDays,
  doneDates: done,
  skipDates: skip,
  repeatEnd: end,
);

List<String> _days(List<TodoItem> todos) => [
  for (final t in todos) dateKeyFor(t.dueDate!),
];

class _FakeService extends Fake implements FirestoreService {
  final added = <TodoItem>[];
  final skipped = <String>[];
  final updated = <TodoItem>[];

  @override
  Future<void> addTodo(TodoItem todo) async => added.add(todo);
  @override
  Future<void> updateTodo(TodoItem todo) async => updated.add(todo);
  @override
  Future<void> skipRepeatOn(String todoId, DateTime day) async =>
      skipped.add('$todoId ${dateKeyFor(day)}');
}

void main() {
  group('expandRepeats', () {
    test('shows a weekly todo on its weekdays only, from its start', () {
      final out = expandRepeats([
        _series(weekdays: [DateTime.tuesday, DateTime.thursday]),
      ], until: DateTime(2026, 10, 18));
      expect(_days(out), [
        '2026-10-06',
        '2026-10-08',
        '2026-10-13',
        '2026-10-15',
      ]);
      expect(out.every((t) => t.id == 'gym'), isTrue);
    });

    test('each day has its own check, skip and end', () {
      final out = expandRepeats([
        _series(
          weekdays: [DateTime.monday, DateTime.wednesday],
          done: ['2026-10-07'],
          skip: ['2026-10-12'],
          end: DateTime(2026, 10, 14),
        ),
      ], until: DateTime(2026, 12, 31));
      expect(_days(out), ['2026-10-05', '2026-10-07', '2026-10-14']);
      expect([for (final t in out) t.isDone], [false, true, false]);
    });

    test('a month day that a month lacks is just skipped', () {
      final out = expandRepeats([
        _series(monthDays: [31]),
      ], until: DateTime(2027, 1, 31));
      expect(_days(out), ['2026-10-31', '2026-12-31', '2027-01-31']);
    });

    test('one-day todos pass through untouched', () {
      final once = _series();
      expect(expandRepeats([once]), [same(once)]);
    });

    test('a day copy writes back the series, not its own day', () {
      final day = expandRepeats([
        _series(weekdays: [DateTime.friday], done: ['2026-10-09']),
      ], until: DateTime(2026, 10, 9)).single;
      expect(day.isDone, isTrue);
      final data = day.copyWith(title: '헬스장').toFirestore();
      expect(
        (data['dueDate'] as Timestamp).toDate(),
        DateTime(2026, 10, 5, 14, 30),
      );
      expect(data['isDone'], isFalse);
      expect(data['doneDates'], ['2026-10-09']);
    });
  });

  Future<_FakeService> pumpSheet(
    WidgetTester tester, {
    TodoItem? existing,
    DateTime? initialDate,
  }) async {
    await initializeDateFormatting('ko_KR');
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = _FakeService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreServiceProvider.overrideWithValue(service),
          categoriesProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AddEditTodoSheet(
              existing: existing,
              // A Monday.
              initialDate: initialDate ?? DateTime(2026, 10, 5),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  testWidgets('adding a todo that repeats on picked weekdays', (tester) async {
    final service = await pumpSheet(tester);
    await tester.enterText(find.byType(TextField).first, '알바');
    await tester.tap(find.text('요일마다'));
    await tester.pump();
    // Starts with its own day (Monday) picked; add Thursday.
    expect(find.textContaining('매주 월요일'), findsOneWidget);
    await tester.tap(find.text('목'));
    await tester.pump();
    expect(find.text('10월 5일부터 매주 월, 목요일에 알아서 떠요'), findsOneWidget);
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    final todo = service.added.single;
    expect(todo.repeatWeekdays, [DateTime.monday, DateTime.thursday]);
    expect(todo.repeatMonthDays, isEmpty);
  });

  testWidgets('adding a todo that repeats on days of the month', (
    tester,
  ) async {
    final service = await pumpSheet(tester);
    await tester.enterText(find.byType(TextField).first, '월세 내기');
    await tester.tap(find.text('매달 날짜'));
    await tester.pump();
    await tester.tap(find.text('25'));
    await tester.pump();
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    expect(service.added.single.repeatMonthDays, [5, 25]);
  });

  testWidgets('just for the day stays a plain todo', (tester) async {
    final service = await pumpSheet(tester);
    await tester.enterText(find.byType(TextField).first, '장보기');
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    expect(service.added.single.isRepeating, isFalse);
  });

  testWidgets('deleting one day of a repeat keeps the rest', (tester) async {
    final day = expandRepeats([
      _series(weekdays: [DateTime.wednesday]),
    ], until: DateTime(2026, 10, 7)).single;
    final service = await pumpSheet(tester, existing: day);
    expect(find.text('10월 5일부터 매주 수요일에 알아서 떠요'), findsOneWidget);

    await tester.tap(find.byTooltip('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 날만 삭제'));
    await tester.pumpAndSettle();

    expect(service.skipped, ['gym 2026-10-07']);
  });

  // Far enough ahead that "today" never passes these days.
  final tuesday2030 = DateTime(2030, 1, 1);

  testWidgets('several days of a repeat go at once, and come back', (
    tester,
  ) async {
    final day = expandRepeats([
      TodoItem(
        id: 'gym',
        title: '헬스',
        categoryId: null,
        isDone: false,
        dueDate: tuesday2030,
        createdAt: tuesday2030,
        order: 0,
        repeatWeekdays: const [DateTime.tuesday, DateTime.thursday],
        skipDates: const ['2030-01-08'],
      ),
    ], until: DateTime(2030, 1, 3)).last;
    final service = await pumpSheet(tester, existing: day);

    Text label(String text) => tester.widget<Text>(find.text(text));
    expect(label('1/1 (화)').style?.decoration, isNull);
    // Taken off earlier with "이 날만 삭제": shown struck through.
    expect(label('1/8 (화)').style?.decoration, TextDecoration.lineThrough);

    await tester.tap(find.text('1/10 (목)'));
    await tester.tap(find.text('1/15 (화)'));
    await tester.tap(find.text('1/8 (화)'));
    await tester.pump();
    expect(label('1/10 (목)').style?.decoration, TextDecoration.lineThrough);
    expect(label('1/8 (화)').style?.decoration, isNull);

    // Ten at a time; more on request.
    expect(find.text('2/5 (화)'), findsNothing);
    await tester.tap(find.text('더 보기'));
    await tester.pump();
    expect(find.text('2/5 (화)'), findsOneWidget);

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(service.updated.single.skipDates, ['2030-01-10', '2030-01-15']);
  });

  testWidgets('days can be taken off while making the repeat', (tester) async {
    final service = await pumpSheet(tester, initialDate: tuesday2030);
    await tester.enterText(find.byType(TextField).first, '헬스');
    await tester.tap(find.text('요일마다'));
    await tester.pump();
    await tester.tap(find.text('1/8 (화)'));
    await tester.pump();
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    final todo = service.added.single;
    expect(todo.skipDates, ['2030-01-08']);
    expect(
      [
        for (final t in expandRepeats([todo], until: DateTime(2030, 1, 15)))
          dateKeyFor(t.dueDate!),
      ],
      ['2030-01-01', '2030-01-15'],
    );
  });
}
