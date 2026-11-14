import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_on/models/category.dart';
import 'package:todo_on/models/todo_item.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/screens/home_screen.dart';
import 'package:todo_on/services/firestore_service.dart';
import 'package:todo_on/widgets/todo_selection.dart';
import 'package:todo_on/widgets/todo_tile.dart';

class _FakeMoves extends Fake implements FirestoreService {
  final moved = <String>[];
  DateTime? movedTo;

  @override
  Future<void> moveTodosToDay(Iterable<String> todoIds, DateTime day) async {
    moved.addAll(todoIds);
    movedTo = day;
  }
}

final _day = DateTime(2026, 11, 14);

TodoItem _todo(String id, String title, int order, {bool repeat = false}) =>
    TodoItem(
      id: id,
      title: title,
      categoryId: 'study',
      isDone: false,
      dueDate: _day,
      createdAt: _day,
      order: order,
      repeatWeekdays: repeat ? const [6] : const [],
    );

void main() {
  late _FakeMoves service;
  late ProviderContainer container;

  Future<void> pumpHome(WidgetTester tester) async {
    await initializeDateFormatting('ko_KR');
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    service = _FakeMoves();
    container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        userProfileProvider.overrideWith((ref) => Stream.value(null)),
        firestoreServiceProvider.overrideWithValue(service),
        updateInfoProvider.overrideWith((ref) => Future.value(null)),
        isAndroidPlatformProvider.overrideWithValue(false),
        profileDocProvider.overrideWith((ref) => Stream.value(null)),
        selectedDateProvider.overrideWith((ref) => _day),
        focusedMonthProvider.overrideWith((ref) => _day),
        categoriesProvider.overrideWith(
          (ref) => Stream.value(const [
            TodoCategory(
              id: 'study',
              name: 'STUDY',
              colorValue: 0xFF42A5F5,
              order: 0,
            ),
          ]),
        ),
        todosProvider.overrideWith(
          (ref) => Stream.value([
            _todo('a', '영어 단어', 0),
            _todo('b', '수학 문제', 1),
            _todo('c', '독서', 2),
            _todo('r', '헬스', 3, repeat: true),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Finder row(String id) =>
      find.byWidgetPredicate((w) => w is TodoTile && w.todo.id == id);

  testWidgets('a box dragged with the mouse selects the rows it touches', (
    tester,
  ) async {
    await pumpHome(tester);
    final a = tester.getRect(row('a'));
    final b = tester.getRect(row('b'));
    // From the empty margin left of the rows, down across a and b.
    final gesture = await tester.startGesture(
      Offset(a.left + 6, a.top + 4),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(Offset(a.left + 8, a.top + 20));
    await gesture.moveTo(Offset(b.left + 40, b.center.dy));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(container.read(selectedTodoIdsProvider), {'a', 'b'});
    expect(tester.widget<TodoTile>(row('a')).selected, isTrue);
    expect(tester.widget<TodoTile>(row('c')).selected, isFalse);
    expect(find.text('2개 선택'), findsOneWidget);
  });

  testWidgets('다음 날로 moves the selection; a repeat stays put', (tester) async {
    await pumpHome(tester);
    container.read(selectedTodoIdsProvider.notifier).state = {'a', 'c', 'r'};
    await tester.pump();

    await tester.tap(find.text('다음 날로'));
    await tester.pump();

    expect(service.moved, ['a', 'c']);
    expect(service.movedTo, DateTime(2026, 11, 15));
    expect(container.read(selectedTodoIdsProvider), isEmpty);
    expect(find.textContaining('반복하는 할 일 1개는 그대로'), findsOneWidget);
  });

  testWidgets('long press picks a row, then a tap picks another', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.longPress(
      find.descendant(of: row('a'), matching: find.text('영어 단어')),
    );
    await tester.pump();
    await tester.tap(find.descendant(of: row('c'), matching: find.text('독서')));
    await tester.pump();
    expect(container.read(selectedTodoIdsProvider), {'a', 'c'});
    // A click on the empty space lets go.
    final c = tester.getRect(row('c'));
    final click = await tester.startGesture(
      Offset(c.left + 40, c.bottom + 120),
      kind: PointerDeviceKind.mouse,
    );
    await click.up();
    await tester.pump();
    expect(container.read(selectedTodoIdsProvider), isEmpty);
  });

  testWidgets('dragging a picked row onto a calendar day moves them all', (
    tester,
  ) async {
    await pumpHome(tester);
    container.read(selectedTodoIdsProvider.notifier).state = {'a', 'b'};
    await tester.pump();

    final handle = find.descendant(
      of: row('a'),
      matching: find.byIcon(Icons.drag_indicator),
    );
    final target = find.text('20').first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(service.moved, unorderedEquals(['a', 'b']));
    expect(service.movedTo, DateTime(2026, 11, 20));
  });
}
