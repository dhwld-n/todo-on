import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_on/models/diary_group.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/widgets/calendar_sidebar.dart';

List<Override> _overrides() => [
  authStateProvider.overrideWith((ref) => Stream.value(null)),
  firestoreServiceProvider.overrideWithValue(null),
  todosProvider.overrideWith((ref) => Stream.value(const [])),
  categoriesProvider.overrideWith((ref) => Stream.value(const [])),
  selectedDateProvider.overrideWith((ref) => DateTime(2026, 9, 28)),
  focusedMonthProvider.overrideWith((ref) => DateTime(2026, 9, 15)),
  // 내 일기 on the 3rd and 10th.
  myDiaryDatesProvider.overrideWith(
    (ref) => Stream.value({'2026-09-03', '2026-09-10'}),
  ),
  // A 1:1 exchange diary on the 10th, a diary group on the 20th.
  followingProvider.overrideWith((ref) => Stream.value(['friend_a1'])),
  sharedDiaryDatesProvider.overrideWith(
    (ref, uid) => Stream.value({'2026-09-10'}),
  ),
  myDiaryGroupsProvider.overrideWith(
    (ref) => Stream.value(const [
      DiaryGroup(id: 'g1', members: ['', 'friend_a1'], createdBy: ''),
    ]),
  ),
  diaryGroupDatesProvider.overrideWith(
    (ref, id) => Stream.value({'2026-09-20'}),
  ),
];

Future<void> _pump(WidgetTester tester, double width) async {
  await initializeDateFormatting('ko_KR');
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(),
      child: const MaterialApp(home: Scaffold(body: CalendarSidebar())),
    ),
  );
  await tester.pumpAndSettle();
}

Color _markColor(WidgetTester tester, String key) => tester
    .widget<Icon>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(Icon),
      ),
    )
    .color!;

void main() {
  testWidgets('diary days get a marker per kind, in its own color', (
    tester,
  ) async {
    await _pump(tester, 800);

    expect(find.byKey(const ValueKey('my-diary-2026-09-03')), findsOneWidget);
    expect(find.byKey(const ValueKey('my-diary-2026-09-10')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('exchange-diary-2026-09-10')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('exchange-diary-2026-09-20')),
      findsOneWidget,
    );
    // No cross-over: each day only shows the kinds it actually has.
    expect(
      find.byKey(const ValueKey('exchange-diary-2026-09-03')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('my-diary-2026-09-20')), findsNothing);
    expect(find.byKey(const ValueKey('my-diary-2026-09-28')), findsNothing);

    expect(_markColor(tester, 'my-diary-2026-09-03'), kMyDiaryColor);
    expect(
      _markColor(tester, 'exchange-diary-2026-09-20'),
      kExchangeDiaryColor,
    );
    expect(kMyDiaryColor, isNot(kExchangeDiaryColor));
    expect(find.text('내 일기'), findsOneWidget);
    expect(find.text('교환일기'), findsOneWidget);
  });

  testWidgets(
    'legend sits under the month title, which still opens the picker',
    (tester) async {
      await _pump(tester, 800);

      final title = tester.getRect(find.text('2026년 9월'));
      final legend = tester.getRect(find.text('내 일기'));
      final weekday = tester.getRect(find.text('일').first);
      expect(legend.top, greaterThan(title.bottom));
      expect(legend.bottom, lessThan(weekday.top));

      await tester.tap(find.text('2026년 9월'));
      await tester.pumpAndSettle();
      expect(find.text('완료'), findsOneWidget);
    },
  );

  testWidgets('on a phone-width calendar the markers clear the day number', (
    tester,
  ) async {
    await _pump(tester, 360);

    final myMark = tester.getRect(
      find.byKey(const ValueKey('my-diary-2026-09-10')),
    );
    final exMark = tester.getRect(
      find.byKey(const ValueKey('exchange-diary-2026-09-10')),
    );
    final number = tester.getRect(
      find.descendant(
        of: find
            .ancestor(
              of: find.byKey(const ValueKey('my-diary-2026-09-10')),
              matching: find.byType(Row),
            )
            .first,
        matching: find.text('10'),
      ),
    );
    expect(myMark.overlaps(number), isFalse, reason: '$myMark vs $number');
    expect(exMark.overlaps(number), isFalse, reason: '$exMark vs $number');
    expect(myMark.overlaps(exMark), isFalse);
  });
}
