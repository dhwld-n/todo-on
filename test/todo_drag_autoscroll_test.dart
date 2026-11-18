import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_on/models/category.dart';
import 'package:todo_on/models/todo_item.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/screens/home_screen.dart';
import 'package:todo_on/widgets/todo_tile.dart';

final _day = DateTime(2026, 11, 18);

void main() {
  test('autoScrollStep: still in the middle, faster toward an edge', () {
    expect(autoScrollStep(300, 600), 0);
    expect(autoScrollStep(32, 600), -8);
    expect(autoScrollStep(-50, 600), -16);
    expect(autoScrollStep(568, 600), 8);
    expect(autoScrollStep(700, 600), 16);
  });

  testWidgets('dragging a todo to an edge scrolls the list that way', (
    tester,
  ) async {
    await initializeDateFormatting('ko_KR');
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          userProfileProvider.overrideWith((ref) => Stream.value(null)),
          firestoreServiceProvider.overrideWithValue(null),
          updateInfoProvider.overrideWith((ref) => Future.value(null)),
          isAndroidPlatformProvider.overrideWithValue(true),
          mobileCalendarExpandedProvider.overrideWith((ref) => false),
          profileDocProvider.overrideWith((ref) => Stream.value(null)),
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
          todosProvider.overrideWith(
            (ref) => Stream.value([
              for (var i = 0; i < 20; i++)
                TodoItem(
                  id: 't$i',
                  title: '할 일 $i',
                  categoryId: 'school',
                  isDone: false,
                  dueDate: _day,
                  createdAt: _day,
                  order: i,
                ),
            ]),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final list = find
        .ancestor(of: find.text('할 일 0'), matching: find.byType(Scrollable))
        .first;
    double offset() => tester.state<ScrollableState>(list).position.pixels;
    final viewport = tester.getRect(list);
    expect(offset(), 0);

    // Grab the first row's handle and hold it at the bottom edge.
    final handle = find.descendant(
      of: find.byWidgetPredicate((w) => w is TodoTile && w.todo.id == 't0'),
      matching: find.byIcon(Icons.drag_indicator),
    );
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveTo(Offset(viewport.center.dx, viewport.bottom - 8));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final down = offset();
    expect(down, greaterThan(100));

    // Then up to the top edge: it scrolls back.
    await gesture.moveTo(Offset(viewport.center.dx, viewport.top + 8));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(offset(), lessThan(down));

    // Let go: it stops.
    await gesture.up();
    await tester.pump();
    final stopped = offset();
    await tester.pump(const Duration(milliseconds: 200));
    expect(offset(), stopped);
  });
}
