import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/widgets/calendar_sidebar.dart';

void main() {
  testWidgets('a finger drag on the month grid scrolls the calendar', (
    tester,
  ) async {
    // Phone-sized: six 104px week rows don't fit, so it has to scroll.
    await initializeDateFormatting('ko_KR');
    tester.view.physicalSize = const Size(360, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          firestoreServiceProvider.overrideWithValue(null),
          todosProvider.overrideWith((ref) => Stream.value(const [])),
          categoriesProvider.overrideWith((ref) => Stream.value(const [])),
          selectedDateProvider.overrideWith((ref) => DateTime(2026, 9, 28)),
          focusedMonthProvider.overrideWith((ref) => DateTime(2026, 9, 15)),
          myDiaryDatesProvider.overrideWith((ref) => Stream.value({})),
          followingProvider.overrideWith((ref) => Stream.value(const [])),
          myDiaryGroupsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(home: Scaffold(body: CalendarSidebar())),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));

    // Drag starting on a day cell, the way a thumb would.
    await tester.dragFrom(
      tester.getCenter(find.text('16')),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(100));
  });
}
