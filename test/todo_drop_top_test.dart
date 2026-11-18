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

class _FakeOrder extends Fake implements FirestoreService {
  final calls = <(String, String?, List<String>)>[];

  @override
  Future<void> moveTodo({
    required String todoId,
    required String? categoryId,
    required bool categoryIsPrivate,
    required List<String> destinationOrderedIds,
  }) async => calls.add((todoId, categoryId, destinationOrderedIds));
}

final _day = DateTime(2026, 11, 18);

TodoItem _todo(String id, String title, int order, {String cat = 'school'}) =>
    TodoItem(
      id: id,
      title: title,
      categoryId: cat,
      isDone: false,
      dueDate: _day,
      createdAt: _day,
      order: order,
    );

void main() {
  test('topOrderedIds puts the moved ones first, the rest as they were', () {
    expect(topOrderedIds(['d'], ['a', 'b', 'c', 'd']), ['d', 'a', 'b', 'c']);
    expect(topOrderedIds(['c', 'a'], ['a', 'b', 'c']), ['c', 'a', 'b']);
    expect(topOrderedIds(['x'], ['a', 'b']), ['x', 'a', 'b']);
  });

  late _FakeOrder service;
  late ProviderContainer container;

  Future<void> pumpHome(WidgetTester tester) async {
    await initializeDateFormatting('ko_KR');
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    service = _FakeOrder();
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
              id: 'school',
              name: 'SCHOOL',
              colorValue: 0xFF78909C,
              order: 0,
            ),
            TodoCategory(
              id: 'project',
              name: 'PROJECT',
              colorValue: 0xFF26C6DA,
              order: 1,
            ),
          ]),
        ),
        todosProvider.overrideWith(
          (ref) => Stream.value([
            _todo('a', '창업입문 영상 보기', 0),
            _todo('b', '자구 과제', 1),
            _todo('c', '플기프 과제', 2),
            _todo('p', '포폴 수정', 0, cat: 'project'),
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

  Finder handleOf(String id) => find.descendant(
    of: find.byWidgetPredicate((w) => w is TodoTile && w.todo.id == id),
    matching: find.byIcon(Icons.drag_indicator),
  );

  Future<void> dragTo(WidgetTester tester, String id, Finder target) async {
    final gesture = await tester.startGesture(tester.getCenter(handleOf(id)));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  testWidgets('the strip only shows while dragging', (tester) async {
    await pumpHome(tester);
    expect(find.text(' 맨 위로'), findsNothing);
    final gesture = await tester.startGesture(tester.getCenter(handleOf('c')));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    expect(find.text(' 맨 위로'), findsOneWidget);
    expect(find.text('SCHOOL'), findsWidgets);
    await gesture.up();
    await tester.pump();
    expect(find.text(' 맨 위로'), findsNothing);
  });

  testWidgets('dropped on the strip, a todo goes first in its category', (
    tester,
  ) async {
    await pumpHome(tester);
    await dragTo(tester, 'c', find.text(' 맨 위로'));
    // Records hold the list by identity, so check each part.
    final (id, category, order) = service.calls.single;
    expect((id, category), ('c', 'school'));
    expect(order, ['c', 'a', 'b']);
  });

  testWidgets('dropped on a category name, it goes first in that category', (
    tester,
  ) async {
    await pumpHome(tester);
    // The header's name, not the category label under the 포폴 row.
    await dragTo(tester, 'b', find.text('PROJECT').first);
    final (id, category, order) = service.calls.single;
    expect((id, category), ('b', 'project'));
    expect(order, ['b', 'p']);
  });

  testWidgets('a selection dropped on the strip lands on top, in order', (
    tester,
  ) async {
    await pumpHome(tester);
    container.read(selectedTodoIdsProvider.notifier).state = {'b', 'c'};
    await tester.pump();
    await dragTo(tester, 'c', find.text(' 맨 위로'));
    for (final (_, _, order) in service.calls) {
      expect(order, ['b', 'c', 'a']);
    }
    expect(service.calls.map((c) => c.$1), unorderedEquals(['b', 'c']));
    expect(container.read(selectedTodoIdsProvider), isEmpty);
  });
}
