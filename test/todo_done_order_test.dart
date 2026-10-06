import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_on/models/category.dart';
import 'package:todo_on/models/todo_item.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/screens/home_screen.dart';
import 'package:todo_on/widgets/todo_tile.dart';

final _day = DateTime(2026, 9, 28);

TodoItem _todo(String title, int order, {bool done = false}) => TodoItem(
  id: title,
  title: title,
  categoryId: 'school',
  isDone: done,
  dueDate: _day,
  createdAt: _day,
  order: order,
);

void main() {
  test('unchecked todos come first, each part in its own order', () {
    final list = [
      _todo('개인회고', 0, done: true),
      _todo('AIP 과제5 제출', 3),
      _todo('멘토링회고', 1, done: true),
      _todo('AIP 과제 002', 2),
    ]..sort(compareTodosForList);
    expect([for (final t in list) t.title], [
      'AIP 과제 002',
      'AIP 과제5 제출',
      '개인회고',
      '멘토링회고',
    ]);
  });

  testWidgets('the day list shows unchecked todos above checked ones', (
    tester,
  ) async {
    await initializeDateFormatting('ko_KR');
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        userProfileProvider.overrideWith((ref) => Stream.value(null)),
        firestoreServiceProvider.overrideWithValue(null),
        updateInfoProvider.overrideWith((ref) => Future.value(null)),
        isAndroidPlatformProvider.overrideWithValue(false),
        selectedDateProvider.overrideWith((ref) => _day),
        categoriesProvider.overrideWith(
          (ref) => Stream.value(const [
            TodoCategory(
              id: 'school',
              name: 'SCHOOL',
              colorValue: 0xFF78909C,
              order: 0,
            ),
          ]),
        ),
        // The screenshot's order: two checked ones dragged to the top.
        todosProvider.overrideWith(
          (ref) => Stream.value([
            _todo('개인회고', 0, done: true),
            _todo('멘토링회고', 1, done: true),
            _todo('AIP 과제 002', 2),
            _todo('AIP 과제5 제출', 3),
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
    // Not pumpAndSettle: the app bar's BlinkingDot repeats forever.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final shown = tester
        .widgetList<TodoTile>(find.byType(TodoTile))
        .map((t) => t.todo.title)
        .toList();
    expect(shown, ['AIP 과제 002', 'AIP 과제5 제출', '개인회고', '멘토링회고']);
  });
}
