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

TodoItem _todo(String id, String title, int order) => TodoItem(
  id: id,
  title: title,
  categoryId: 'study',
  isDone: false,
  dueDate: _day,
  createdAt: _day,
  order: order,
);

void main() {
  testWidgets('dragging a todo shows a card, a drop box, and fades the row', (
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

    expect(find.text('여기에 놓여요'), findsNothing);
    // Titles also show up small in the calendar, so count them up front.
    final titleCountBefore = find.text('영어 단어').evaluate().length;
    Opacity rowOpacity(String id) => tester.widget<Opacity>(
      find.byWidgetPredicate(
        (w) =>
            w is Opacity &&
            w.child is TodoTile &&
            (w.child as TodoTile).todo.id == id,
      ),
    );
    expect(rowOpacity('a').opacity, 1);

    // Grab 영어 단어's handle and hover it over 독서.
    final handles = find.byIcon(Icons.drag_indicator);
    final gesture = await tester.startGesture(tester.getCenter(handles.first));
    await tester.pump();
    await gesture.moveTo(
      tester.getCenter(
        find.byWidgetPredicate((w) => w is TodoTile && w.todo.id == 'c'),
      ),
    );
    await tester.pump();
    await tester.pump();

    // The drop spot is a box, the card follows the pointer (title shown twice:
    // the row and the card), and the original row is faded.
    expect(find.text('여기에 놓여요'), findsOneWidget);
    expect(find.text('영어 단어').evaluate().length, titleCountBefore + 1);
    expect(container.read(draggingTodoIdProvider), 'a');
    expect(rowOpacity('a').opacity, lessThan(1));
    expect(rowOpacity('b').opacity, 1);

    await gesture.up();
    await tester.pump();
    expect(container.read(draggingTodoIdProvider), isNull);
    expect(find.text('여기에 놓여요'), findsNothing);
    expect(rowOpacity('a').opacity, 1);
  });
}
