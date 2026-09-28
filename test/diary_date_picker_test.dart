import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/widgets/diary_pane.dart';

void main() {
  // The Android layout has no calendar outside the TODO tab, so the diary's
  // own date title is the only way to move to another day there.
  testWidgets('tapping the diary date lets you pick another day', (
    tester,
  ) async {
    await initializeDateFormatting('ko_KR');
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        firestoreServiceProvider.overrideWithValue(null),
        diaryEntryProvider.overrideWith((ref, key) => Stream.value(null)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: DiaryPane(date: DateTime(2026, 9, 28))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('2026년 9월 28일 월요일'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(container.read(selectedDateProvider), DateTime(2026, 9, 15));
    expect(container.read(focusedMonthProvider).month, 9);
  });

  testWidgets('desktop width keeps the date and tab chips on one line', (
    tester,
  ) async {
    await initializeDateFormatting('ko_KR');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          firestoreServiceProvider.overrideWithValue(null),
          diaryEntryProvider.overrideWith((ref, key) => Stream.value(null)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 600,
              child: DiaryPane(date: DateTime(2026, 9, 28)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final date = tester.getRect(find.textContaining('9월 28일'));
    final chip = tester.getRect(find.widgetWithText(ChoiceChip, '교환일기'));
    expect((date.center.dy - chip.center.dy).abs(), lessThan(4));
    // Chips stay pushed to the right edge (inside the 20px pane padding).
    final pane = tester.getRect(find.byType(DiaryPane));
    expect(chip.right, closeTo(pane.right - 20, 1));
  });
}
