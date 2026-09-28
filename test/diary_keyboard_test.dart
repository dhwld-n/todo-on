import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_on/models/shared_diary_entry.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/screens/home_screen.dart';

const _friends = [
  'friend_a1',
  'friend_b2',
  'friend_c3',
  'friend_d4',
  'friend_e5',
  'friend_f6',
  'friend_g7',
];

final _entry = SharedDiaryEntry(
  dateKey: '2026-09-28',
  content: '아 덥다\n\n\nㅇㅈ',
  updatedAt: DateTime(2026, 9, 28, 11, 44),
  updatedBy: 'friend_a1',
  segments: const [DiarySegment(uid: 'friend_a1', upTo: 9)],
);

List<Override> _overrides() => [
  authStateProvider.overrideWith((ref) => Stream.value(null)),
  userProfileProvider.overrideWith((ref) => Stream.value(null)),
  firestoreServiceProvider.overrideWithValue(null),
  updateInfoProvider.overrideWith((ref) => Future.value(null)),
  isAndroidPlatformProvider.overrideWithValue(true),
  contentModeProvider.overrideWith((ref) => ContentMode.diary),
  diaryTabProvider.overrideWith((ref) => DiaryTab.shared),
  selectedDateProvider.overrideWith((ref) => DateTime(2026, 9, 28)),
  followingProvider.overrideWith((ref) => Stream.value(_friends)),
  friendProfileProvider.overrideWith(
    (ref, uid) => Stream.value({'nickname': '친구$uid'.substring(0, 4)}),
  ),
  unseenSharedDiaryDatesProvider.overrideWith(
    (ref, uid) => Stream.value(const <String>[]),
  ),
  sharedDiaryEntryProvider.overrideWith((ref, key) => Stream.value(_entry)),
];

void main() {
  testWidgets('diary input stays visible above the keyboard on a phone', (
    tester,
  ) async {
    await initializeDateFormatting('ko_KR');
    // A typical phone (360x780 logical) with a status bar and a Korean
    // keyboard (suggestion strip included) open.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 24 * 3);
    tester.view.viewPadding = const FakeViewPadding(top: 24 * 3);
    tester.view.viewInsets = const FakeViewPadding(bottom: 340 * 3);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    // Not pumpAndSettle: the app bar's BlinkingDot repeats forever.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    final rect = tester.getRect(field);
    const keyboardTop = 780.0 - 340.0;
    // Room for a few lines of typing, and fully above the keyboard.
    expect(rect.height, greaterThan(80), reason: 'field rect: $rect');
    expect(rect.bottom, lessThanOrEqualTo(keyboardTop));
  });
}
