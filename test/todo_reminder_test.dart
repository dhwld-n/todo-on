import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_on/models/todo_item.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/services/firestore_service.dart';
import 'package:todo_on/services/reminder_service.dart';
import 'package:todo_on/widgets/add_todo_sheet.dart';

TodoItem _todo(
  String title,
  DateTime day, {
  int? remind,
  bool done = false,
  List<int> weekdays = const [],
}) => TodoItem(
  id: title,
  title: title,
  categoryId: null,
  isDone: done,
  dueDate: day,
  createdAt: day,
  order: 0,
  remindMinutes: remind,
  repeatWeekdays: weekdays,
);

class _FakeService extends Fake implements FirestoreService {
  final added = <TodoItem>[];
  final updated = <TodoItem>[];

  @override
  Future<void> addTodo(TodoItem todo) async => added.add(todo);
  @override
  Future<void> updateTodo(TodoItem todo) async => updated.add(todo);
}

void main() {
  // Monday 2026-10-05, 12:00.
  final now = DateTime(2026, 10, 5, 12);

  test('only unchecked todos with a time still ahead get a reminder', () {
    final reminders = upcomingReminders([
      _todo('약 먹기', DateTime(2026, 10, 5), remind: 9 * 60), // passed
      _todo('헬스', DateTime(2026, 10, 5), remind: 19 * 60),
      _todo('장보기', DateTime(2026, 10, 5), remind: 20 * 60, done: true),
      _todo('일기', DateTime(2026, 10, 5)), // no time
      _todo('알바', DateTime(2026, 10, 6), remind: 8 * 60 + 30),
    ], now);
    expect([for (final r in reminders) r.title], ['헬스', '알바']);
    expect(reminders.first.at, DateTime(2026, 10, 5, 19));
    expect(reminders.last.at, DateTime(2026, 10, 6, 8, 30));
  });

  test('a repeat reminds on each of its days, soonest first, capped', () {
    final days = expandRepeats([
      _todo(
        '헬스',
        DateTime(2026, 10, 5),
        remind: 19 * 60,
        weekdays: [DateTime.tuesday, DateTime.thursday],
      ),
    ], until: DateTime(2026, 12, 31));
    final reminders = upcomingReminders(days, now);
    expect([for (final r in reminders) r.at.day], [6, 8, 13, 15]);
    expect({for (final r in reminders) r.id}, hasLength(4));
    expect(upcomingReminders(days, now, max: 2), hasLength(2));
  });

  Future<_FakeService> pumpSheet(
    WidgetTester tester, {
    TodoItem? existing,
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
              initialDate: DateTime(2026, 10, 5),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  testWidgets('picking a time saves it with the todo', (tester) async {
    final service = await pumpSheet(tester);
    await tester.enterText(find.byType(TextField).first, '약 먹기');
    await tester.tap(find.text('시간 정하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('9:00 AM'), findsOneWidget);
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    expect(service.added.single.remindMinutes, 9 * 60);
  });

  testWidgets('the time can be taken off again', (tester) async {
    final service = await pumpSheet(
      tester,
      existing: _todo('헬스', DateTime(2026, 10, 5), remind: 19 * 60),
    );
    expect(find.text('7:00 PM'), findsOneWidget);
    await tester.tap(find.byTooltip('알림 끄기'));
    await tester.pump();
    expect(find.text('시간 정하기'), findsOneWidget);
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(service.updated.single.remindMinutes, isNull);
    expect(service.updated.single.toFirestore()['remindMinutes'], isNull);
  });
}
