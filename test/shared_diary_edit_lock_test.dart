import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_on/models/shared_diary_entry.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/widgets/diary_pane.dart';

class _Me extends Fake implements User {
  @override
  String get uid => 'me';
}

const friendText = '친구가 쓴 글\n';
const myText = '내가 이어 쓴 글';

void main() {
  group('splitDiaryEditable', () {
    test('no entry yet - nothing locked', () {
      final (locked, segments) = splitDiaryEditable(null, 'me');
      expect(locked, '');
      expect(segments, isEmpty);
    });

    test('friend wrote last - whole entry locked, nothing to edit', () {
      final entry = SharedDiaryEntry(
        dateKey: 'k',
        content: 'AAAA',
        updatedAt: DateTime(2026),
        updatedBy: 'friend',
        segments: const [DiarySegment(uid: 'friend', upTo: 4)],
      );
      final (locked, segments) = splitDiaryEditable(entry, 'me');
      expect(locked, 'AAAA');
      expect(segments.single.uid, 'friend');
    });

    test('I wrote last after a friend turn - only my tail is editable', () {
      final entry = SharedDiaryEntry(
        dateKey: 'k',
        content: 'AAAABBBB',
        updatedAt: DateTime(2026),
        updatedBy: 'me',
        segments: const [
          DiarySegment(uid: 'friend', upTo: 4),
          DiarySegment(uid: 'me', upTo: 8),
        ],
      );
      final (locked, segments) = splitDiaryEditable(entry, 'me');
      expect(locked, 'AAAA');
      expect(segments.single.uid, 'friend');
      // The editable remainder is content minus the locked prefix.
      expect(entry.content.substring(locked.length), 'BBBB');
    });

    test('only my own turn so far - nothing locked yet', () {
      final entry = SharedDiaryEntry(
        dateKey: 'k',
        content: 'CCCC',
        updatedAt: DateTime(2026),
        updatedBy: 'me',
        segments: const [DiarySegment(uid: 'me', upTo: 4)],
      );
      final (locked, segments) = splitDiaryEditable(entry, 'me');
      expect(locked, '');
      expect(segments, isEmpty);
    });
  });

  group('computeDiarySave', () {
    test('typing nothing and blurring is a no-op - no phantom turn', () {
      final entry = SharedDiaryEntry(
        dateKey: 'k',
        content: 'AAAABBBB',
        updatedAt: DateTime(2026),
        updatedBy: 'me',
        segments: const [
          DiarySegment(uid: 'friend', upTo: 4),
          DiarySegment(uid: 'me', upTo: 8),
        ],
      );
      // Friend taps into the editor (their editable tail starts empty,
      // since it isn't their turn) and taps away without typing.
      final result = computeDiarySave(
        oldEntry: entry,
        lockedPrefix: entry.content,
        typedTail: '',
        myUid: 'friend',
      );
      expect(result, isNull);
    });

    test('actually typing something still saves normally', () {
      final entry = SharedDiaryEntry(
        dateKey: 'k',
        content: 'AAAA',
        updatedAt: DateTime(2026),
        updatedBy: 'friend',
        segments: const [DiarySegment(uid: 'friend', upTo: 4)],
      );
      final result = computeDiarySave(
        oldEntry: entry,
        lockedPrefix: entry.content,
        typedTail: '이어쓰기',
        myUid: 'me',
      );
      expect(result, isNotNull);
      final (content, segments) = result!;
      expect(content, 'AAAA이어쓰기');
      expect(segments.last.uid, 'me');
    });
  });

  testWidgets(
    'tapping a friend-authored entry locks it instead of loading it into the editor',
    (tester) async {
      await initializeDateFormatting('ko_KR');
      const content = '친구가 쓴 글';
      final entry = SharedDiaryEntry(
        dateKey: '2026-09-28',
        content: content,
        updatedAt: DateTime(2026, 9, 28, 10),
        updatedBy: 'friend_a',
        segments: [DiarySegment(uid: 'friend_a', upTo: content.length)],
      );
      final overrides = <Override>[
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        firestoreServiceProvider.overrideWithValue(null),
        diaryTabProvider.overrideWith((ref) => DiaryTab.shared),
        followingProvider.overrideWith((ref) => Stream.value(['friend_a'])),
        friendProfileProvider.overrideWith(
          (ref, uid) => Stream.value({'nickname': '친구'}),
        ),
        unseenSharedDiaryDatesProvider.overrideWith(
          (ref, uid) => Stream.value(const <String>[]),
        ),
        sharedDiaryEntryProvider.overrideWith(
          (ref, key) => Stream.value(entry),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            home: Scaffold(body: DiaryPane(date: DateTime(2026, 9, 28))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bodyFinder = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('친구가 쓴 글'),
      );

      // Enter edit mode by tapping the read-only body.
      await tester.tap(bodyFinder);
      await tester.pumpAndSettle();

      // The friend's text stays visible but outside the editable field.
      expect(bodyFinder, findsOneWidget);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, isEmpty);
    },
  );

  Future<TextField> pumpMyTurn(WidgetTester tester, DateTime date) async {
    await initializeDateFormatting('ko_KR');
    final entry = SharedDiaryEntry(
      dateKey: '2026-09-28',
      content: friendText + myText,
      updatedAt: DateTime(2026, 9, 28, 10),
      updatedBy: 'me',
      segments: const [
        DiarySegment(uid: 'friend_a', upTo: friendText.length),
        DiarySegment(uid: 'me', upTo: friendText.length + myText.length),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(_Me())),
          profileDocProvider.overrideWith((ref) => Stream.value(null)),
          firestoreServiceProvider.overrideWithValue(null),
          diaryTabProvider.overrideWith((ref) => DiaryTab.shared),
          followingProvider.overrideWith((ref) => Stream.value(['friend_a'])),
          friendProfileProvider.overrideWith(
            (ref, uid) => Stream.value({'nickname': '친구'}),
          ),
          unseenSharedDiaryDatesProvider.overrideWith(
            (ref, uid) => Stream.value(const <String>[]),
          ),
          sharedDiaryEntryProvider.overrideWith(
            (ref, key) => Stream.value(entry),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: DiaryPane(date: date)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.widget<TextField>(find.byType(TextField));
  }

  bool shownAbove(String text) => find
      .byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains(text),
      )
      .evaluate()
      .isNotEmpty;

  testWidgets('on the day itself, my own last part stays editable in the box', (
    tester,
  ) async {
    final textField = await pumpMyTurn(tester, DateTime.now());
    expect(textField.controller!.text, myText);
    expect(shownAbove('친구가 쓴 글'), isTrue);
  });

  testWidgets("once the day is over, my part is locked like the friend's", (
    tester,
  ) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final textField = await pumpMyTurn(tester, yesterday);
    expect(textField.controller!.text, isEmpty);
    expect(shownAbove('친구가 쓴 글'), isTrue);
    expect(shownAbove(myText), isTrue);
  });

  test('isPastDay goes by calendar day, not the hour', () {
    final now = DateTime(2026, 9, 29, 0, 5);
    expect(isPastDay(DateTime(2026, 9, 28, 23, 59), now: now), isTrue);
    expect(isPastDay(DateTime(2026, 9, 29), now: now), isFalse);
    expect(isPastDay(DateTime(2026, 9, 30), now: now), isFalse);
  });
}
