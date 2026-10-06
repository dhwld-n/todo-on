import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart' show isSameDay;
import 'package:todo_on/models/todo_item.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/screens/home_screen.dart';

TodoItem _todo(String title, DateTime day) => TodoItem(
  id: title,
  title: title,
  categoryId: null,
  isDone: false,
  dueDate: day,
  createdAt: day,
  order: 0,
);

// The calendar behind the sheet shows titles too.
Finder _inSheet(String text) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

// Not pumpAndSettle: the app bar's BlinkingDot repeats forever.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('in the day sheet, swiping left goes to the next day and '
      'right to the day before, even over a todo', (tester) async {
    await initializeDateFormatting('ko_KR');
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        userProfileProvider.overrideWith((ref) => Stream.value(null)),
        firestoreServiceProvider.overrideWithValue(null),
        updateInfoProvider.overrideWith((ref) => Future.value(null)),
        isAndroidPlatformProvider.overrideWithValue(true),
        mobileCalendarExpandedProvider.overrideWith((ref) => true),
        selectedDateProvider.overrideWith((ref) => DateTime(2026, 9, 1)),
        focusedMonthProvider.overrideWith((ref) => DateTime(2026, 9, 15)),
        categoriesProvider.overrideWith((ref) => Stream.value(const [])),
        todosProvider.overrideWith(
          (ref) => Stream.value([
            _todo('헬스', DateTime(2026, 9, 16)),
            _todo('알바', DateTime(2026, 9, 17)),
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
    await _settle(tester);

    await tester.tap(find.text('16'));
    await _settle(tester);
    expect(_inSheet('헬스'), findsOneWidget);

    DateTime selected() => container.read(selectedDateProvider)!;

    // Mid-swipe the day moves with the finger and the next one slides in
    // beside it, instead of the date just flipping in place.
    final restX = tester.getCenter(_inSheet('헬스')).dx;
    final drag = await tester.startGesture(tester.getCenter(_inSheet('헬스')));
    for (var i = 0; i < 6; i++) {
      await drag.moveBy(const Offset(-25, 0));
      await tester.pump();
    }
    expect(tester.getCenter(_inSheet('헬스')).dx, lessThan(restX - 100));
    expect(_inSheet('알바'), findsOneWidget);
    expect(_inSheet('2026년 9월 17일'), findsOneWidget);
    // Let go short of halfway: it springs back to the same day.
    await drag.up();
    await _settle(tester);
    expect(isSameDay(selected(), DateTime(2026, 9, 16)), isTrue);
    expect(_inSheet('알바'), findsNothing);

    // Over the todo itself: no swipe-to-delete in the way.
    await tester.fling(_inSheet('헬스'), const Offset(-250, 0), 1500);
    await _settle(tester);
    expect(isSameDay(selected(), DateTime(2026, 9, 17)), isTrue);
    expect(_inSheet('알바'), findsOneWidget);
    expect(_inSheet('헬스'), findsNothing);

    await tester.fling(_inSheet('알바'), const Offset(250, 0), 1500);
    await _settle(tester);
    expect(isSameDay(selected(), DateTime(2026, 9, 16)), isTrue);
    expect(_inSheet('헬스'), findsOneWidget);
    expect(find.byType(Dismissible), findsNothing);

    // Past a month's end, the calendar follows.
    for (var i = 0; i < 15; i++) {
      await tester.fling(
        _inSheet('2026년 ${selected().month}월 ${selected().day}일'),
        const Offset(-250, 0),
        1500,
      );
      await _settle(tester);
    }
    expect(isSameDay(selected(), DateTime(2026, 10, 1)), isTrue);
    expect(container.read(focusedMonthProvider).month, 10);
  });
}
