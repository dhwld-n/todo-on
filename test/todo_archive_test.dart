import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_on/models/todo_item.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/services/firestore_service.dart';
import 'package:todo_on/widgets/archive_dialog.dart';

class _FakeTodos extends Fake implements FirestoreService {
  final archived = <String>[];
  final deleted = <String>[];
  final takenOut = <String>[];
  DateTime? takenOutOn;

  @override
  Future<void> archiveTodos(Iterable<String> todoIds) async =>
      archived.addAll(todoIds);

  @override
  Future<void> unarchiveTodos(Iterable<String> todoIds, DateTime day) async {
    takenOut.addAll(todoIds);
    takenOutOn = day;
  }

  @override
  Future<void> deleteTodos(Iterable<String> todoIds) async =>
      deleted.addAll(todoIds);
}

final day = DateTime(2030, 3, 14);

TodoItem _todo(
  String id, {
  DateTime? due,
  List<int> weekdays = const [],
  bool done = false,
}) => TodoItem(
  id: id,
  title: '할 일 $id',
  categoryId: null,
  isDone: done,
  dueDate: due,
  createdAt: DateTime(2030),
  order: 0,
  repeatWeekdays: weekdays,
);

final _todos = [
  _todo('a'),
  _todo('b', done: true),
  _todo('today', due: day),
  _todo('other', due: day.add(const Duration(days: 1))),
  // A repeat's copy for the day: can't go in 보관함.
  _todo('gym', due: day, weekdays: [day.weekday]),
];

Future<_FakeTodos> _pump(WidgetTester tester) async {
  final service = _FakeTodos();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firestoreServiceProvider.overrideWithValue(service),
        todosProvider.overrideWith((ref) => Stream.value(_todos)),
        categoriesProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: MaterialApp(
        home: Scaffold(body: ArchiveDialog(day: day)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

void main() {
  test('보관함 holds dayless todos, never repeats', () {
    expect([for (final t in archivedTodos(_todos)) t.id], ['a', 'b']);
  });

  testWidgets('picked todos come out onto the day chosen, not done', (
    tester,
  ) async {
    final service = await _pump(tester);
    expect(find.text('할 일 a'), findsOneWidget);
    expect(find.text('할 일 b'), findsOneWidget);
    expect(find.text('할 일 today'), findsNothing);

    await tester.tap(find.text('할 일 a'));
    await tester.tap(find.text('할 일 b'));
    await tester.pump();
    await tester.tap(find.text('꺼내기 (2)'));
    await tester.pumpAndSettle();
    // The picker opens on the day the box was opened from.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(service.takenOut, ['a', 'b']);
    expect(service.takenOutOn, day);
  });

  testWidgets('the day\'s own todos can be put in, but not its repeats', (
    tester,
  ) async {
    final service = await _pump(tester);
    await tester.tap(find.text('할 일 넣기'));
    await tester.pumpAndSettle();

    expect(find.text('3월 14일 할 일 넣기'), findsOneWidget);
    expect(find.text('할 일 today'), findsOneWidget);
    expect(find.text('할 일 other'), findsNothing);
    expect(find.text('할 일 gym'), findsNothing);

    await tester.tap(find.text('할 일 today'));
    await tester.pump();
    await tester.tap(find.text('보관함에 넣기 (1)'));
    await tester.pumpAndSettle();
    expect(service.archived, ['today']);
    // Back to the 보관함 list afterwards.
    expect(find.text('보관함'), findsOneWidget);
  });

  testWidgets('nothing picked, nothing to do', (tester) async {
    await _pump(tester);
    final takeOut = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '꺼내기'),
    );
    expect(takeOut.onPressed, isNull);
  });

  testWidgets('지우기 asks first, then deletes', (tester) async {
    final service = await _pump(tester);
    await tester.tap(find.text('할 일 b'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '지우기'));
    await tester.pumpAndSettle();
    expect(find.text('보관함에서 1개를 지울까요?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '지우기'));
    await tester.pumpAndSettle();
    expect(service.deleted, ['b']);
  });
}
