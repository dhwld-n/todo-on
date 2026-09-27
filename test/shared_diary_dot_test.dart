import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_on/models/shared_diary_entry.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/widgets/diary_pane.dart';

final _editedAt = DateTime(2026, 9, 27, 21);

SharedDiaryEntry _entry({
  required String updatedBy,
  Map<String, DateTime> seenAt = const {},
}) => SharedDiaryEntry(
  dateKey: '2026-09-27',
  content: 'text',
  updatedAt: _editedAt,
  updatedBy: updatedBy,
  seenAt: seenAt,
);

void main() {
  group('hasUnseenEditFor', () {
    test('friend edited, I never looked', () {
      expect(_entry(updatedBy: 'friend').hasUnseenEditFor('me'), isTrue);
    });
    test('I saw exactly that edit', () {
      final e = _entry(updatedBy: 'friend', seenAt: {'me': _editedAt});
      expect(e.hasUnseenEditFor('me'), isFalse);
    });
    test('friend edited again after I looked', () {
      final e = _entry(
        updatedBy: 'friend',
        seenAt: {'me': _editedAt.subtract(const Duration(minutes: 5))},
      );
      expect(e.hasUnseenEditFor('me'), isTrue);
    });
    test('I made the last edit', () {
      expect(_entry(updatedBy: 'me').hasUnseenEditFor('me'), isFalse);
    });
  });

  // uids need 8+ chars: chips show a uid prefix before the nickname loads.
  const following = ['friend_a', 'friend_b', 'friend_c'];
  final unseen = {
    'friend_a': ['2026-09-25'], // another date
    'friend_b': <String>[],
    'friend_c': ['2026-09-27'], // the date on screen
  };

  List<Override> overrides() => [
    authStateProvider.overrideWith((ref) => Stream.value(null)),
    firestoreServiceProvider.overrideWithValue(null),
    diaryTabProvider.overrideWith((ref) => DiaryTab.shared),
    followingProvider.overrideWith((ref) => Stream.value(following)),
    friendProfileProvider.overrideWith(
      (ref, uid) => Stream.value({'nickname': uid}),
    ),
    unseenSharedDiaryDatesProvider.overrideWith(
      (ref, uid) => Stream.value(unseen[uid]!),
    ),
    sharedDiaryEntryProvider.overrideWith((ref, key) => Stream.value(null)),
  ];

  Future<ProviderContainer> openDiary(
    WidgetTester tester, {
    String? selectedFriend,
  }) async {
    await initializeDateFormatting('ko_KR');
    final container = ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);
    container.read(sharedDiaryFriendProvider.notifier).state = selectedFriend;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: DiaryPane(date: DateTime(2026, 9, 27))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('friend chips get a dot for unseen edits on any date', (
    tester,
  ) async {
    final container = await openDiary(tester);

    bool dotOn(String name) => tester
        .widget<Badge>(
          find.ancestor(of: find.text(name), matching: find.byType(Badge)),
        )
        .isLabelVisible;
    expect(dotOn('friend_a'), isTrue);
    expect(dotOn('friend_b'), isFalse);
    expect(dotOn('friend_c'), isTrue);

    // friend_a is selected (first): its unseen edit on another date is
    // offered as a jump, and tapping it moves the diary to that date.
    expect(find.text('다른 날 새로 쓴 내용:'), findsOneWidget);
    await tester.tap(find.text('9월 25일'));
    await tester.pumpAndSettle();
    expect(container.read(selectedDateProvider), DateTime(2026, 9, 25));
  });

  testWidgets('no jump row when the only unseen date is the one on screen', (
    tester,
  ) async {
    await openDiary(tester, selectedFriend: 'friend_c');
    expect(find.text('다른 날 새로 쓴 내용:'), findsNothing);
  });

  testWidgets('일기 tab dot is on when any friend has an unseen edit', (
    tester,
  ) async {
    Future<bool> tabDot(Map<String, List<String>> perFriend) async {
      final container = ProviderContainer(
        overrides: [
          followingProvider.overrideWith((ref) => Stream.value(following)),
          unseenSharedDiaryDatesProvider.overrideWith(
            (ref, uid) => Stream.value(perFriend[uid]!),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => Text(
              '${ref.watch(hasUnseenSharedDiaryProvider)}',
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container.read(hasUnseenSharedDiaryProvider);
    }

    expect(await tabDot(unseen), isTrue);
    expect(
      await tabDot({for (final uid in following) uid: <String>[]}),
      isFalse,
    );
  });
}
