import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_on/models/shared_diary_entry.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/services/firestore_service.dart';
import 'package:todo_on/widgets/diary_pane.dart';

class _Me extends Fake implements User {
  @override
  String get uid => 'me';
}

/// Keeps the one day's entry and plays every save back like Firestore does.
class _FakeDiary extends Fake implements FirestoreService {
  SharedDiaryEntry? entry;
  final changes = StreamController<SharedDiaryEntry?>.broadcast();
  var saves = 0;

  _FakeDiary(this.entry);

  @override
  Future<void> saveSharedDiaryEntry(
    String otherUid,
    String dateKey,
    String content,
    List<DiarySegment> segments,
  ) async {
    saves++;
    entry = SharedDiaryEntry(
      dateKey: dateKey,
      content: content,
      updatedAt: DateTime(2026, 9, 28, 11),
      updatedBy: 'me',
      segments: segments,
    );
    changes.add(entry);
  }

  @override
  Future<void> markSharedDiarySeen(
    String otherUid,
    String dateKey,
    DateTime editedAt,
  ) async {}
}

const friendText = '오늘 학교에서 재밌는 일 있었어';

SharedDiaryEntry _friendWrote() => SharedDiaryEntry(
  dateKey: '2026-09-28',
  content: friendText,
  updatedAt: DateTime(2026, 9, 28, 10),
  updatedBy: 'friend_a',
  segments: [DiarySegment(uid: 'friend_a', upTo: friendText.length)],
);

void main() {
  group('appendToDiary', () {
    test('adds my part after what is there, signed as mine', () {
      final (content, segments) = appendToDiary(
        _friendWrote(),
        '  나도 오늘 좋았어\n',
        'me',
      )!;
      expect(content, '$friendText나도 오늘 좋았어');
      expect([for (final s in segments) s.uid], ['friend_a', 'me']);
      expect(segments.last.upTo, content.length);
    });

    test('each save is its own part, even twice in a row', () {
      final (c1, s1) = appendToDiary(null, '첫 번째', 'me')!;
      final second = SharedDiaryEntry(
        dateKey: 'k',
        content: c1,
        updatedAt: DateTime(2026),
        updatedBy: 'me',
        segments: s1,
      );
      final (_, s2) = appendToDiary(second, '두 번째', 'me')!;
      expect([for (final s in s2) s.upTo], [4, 8]);
    });

    test('nothing typed, nothing saved', () {
      expect(appendToDiary(_friendWrote(), '  \n ', 'me'), isNull);
    });

    test('text from before signed parts stays unsigned', () {
      final legacy = SharedDiaryEntry(
        dateKey: 'k',
        content: '옛날 글',
        updatedAt: DateTime(2026),
        updatedBy: 'friend_a',
      );
      final (_, segments) = appendToDiary(legacy, '새 글', 'me')!;
      expect([for (final s in segments) (s.uid, s.upTo)], [('', 4), ('me', 7)]);
    });
  });

  Future<_FakeDiary> pumpDiary(
    WidgetTester tester,
    DateTime date, {
    SharedDiaryEntry? entry,
  }) async {
    await initializeDateFormatting('ko_KR');
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = _FakeDiary(entry ?? _friendWrote());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(_Me())),
          profileDocProvider.overrideWith(
            (ref) => Stream.value({'nickname': '지우'}),
          ),
          firestoreServiceProvider.overrideWithValue(service),
          diaryTabProvider.overrideWith((ref) => DiaryTab.shared),
          followingProvider.overrideWith((ref) => Stream.value(['friend_a'])),
          friendProfileProvider.overrideWith(
            (ref, uid) => Stream.value({'nickname': '친구'}),
          ),
          unseenSharedDiaryDatesProvider.overrideWith(
            (ref, uid) => Stream.value(const <String>[]),
          ),
          sharedDiaryEntryProvider.overrideWith((ref, key) async* {
            yield service.entry;
            yield* service.changes.stream;
          }),
        ],
        child: MaterialApp(
          home: Scaffold(body: DiaryPane(date: date)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  bool shownInDiary(String text) => find
      .byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains(text),
      )
      .evaluate()
      .isNotEmpty;

  String boxText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('saving moves my writing into the diary and empties the box', (
    tester,
  ) async {
    final service = await pumpDiary(tester, DateTime(2026, 9, 28));
    expect(shownInDiary(friendText), isTrue);
    expect(boxText(tester), isEmpty);

    await tester.enterText(find.byType(TextField), '나도 오늘 좋았어');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(service.saves, 1);
    expect(boxText(tester), isEmpty);
    expect(shownInDiary('나도 오늘 좋았어'), isTrue);
    // Signed under my part.
    expect(shownInDiary('- 지우'), isTrue);
    expect(shownInDiary(friendText), isTrue);
  });

  testWidgets('typing alone saves nothing; only the button does', (
    tester,
  ) async {
    final service = await pumpDiary(tester, DateTime(2026, 9, 28));
    await tester.enterText(find.byType(TextField), '아직 쓰는 중');
    await tester.pump(const Duration(seconds: 2));
    // Leaving the box doesn't save it either.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(service.saves, 0);
    expect(boxText(tester), '아직 쓰는 중');
  });

  testWidgets('an earlier day can still be added to', (tester) async {
    final service = await pumpDiary(tester, DateTime(2026, 9, 1));
    await tester.enterText(find.byType(TextField), '늦었지만 덧붙여');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(service.saves, 1);
    expect(boxText(tester), isEmpty);
  });

  // Friend's part, then mine: "일기 기능 테스트 좀 하겟습둥" by me.
  const mine = '일기 기능 테스트 좀 하겟습둥';
  SharedDiaryEntry bothWrote(DateTime day) => SharedDiaryEntry(
    dateKey: dateKeyFor(day),
    content: friendText + mine,
    updatedAt: day,
    updatedBy: 'me',
    segments: [
      DiarySegment(uid: 'friend_a', upTo: friendText.length),
      DiarySegment(uid: 'me', upTo: friendText.length + mine.length),
    ],
  );

  group('replaceDiaryPart', () {
    final entry = SharedDiaryEntry(
      dateKey: 'k',
      content: 'AAABBBCCC',
      updatedAt: DateTime(2026),
      updatedBy: 'me',
      segments: const [
        DiarySegment(uid: 'friend_a', upTo: 3),
        DiarySegment(uid: 'me', upTo: 6),
        DiarySegment(uid: 'friend_a', upTo: 9),
      ],
    );

    test('a middle part changes; the ones after keep their text', () {
      final (content, segments) = replaceDiaryPart(entry, 1, 'bbbbb');
      expect(content, 'AAAbbbbbCCC');
      expect([for (final s in segments) s.upTo], [3, 8, 11]);
      expect([for (final s in segments) s.uid], ['friend_a', 'me', 'friend_a']);
    });

    test('blank takes the part out', () {
      final (content, segments) = replaceDiaryPart(entry, 1, '  ');
      expect(content, 'AAACCC');
      expect(
        [for (final s in segments) (s.uid, s.upTo)],
        [('friend_a', 3), ('friend_a', 6)],
      );
    });
  });

  test('isPastDay goes by calendar day, not the hour', () {
    final now = DateTime(2026, 9, 29, 0, 5);
    expect(isPastDay(DateTime(2026, 9, 28, 23, 59), now: now), isTrue);
    expect(isPastDay(DateTime(2026, 9, 29), now: now), isFalse);
  });

  testWidgets('my own part can be fixed; the friend\'s has no button', (
    tester,
  ) async {
    final today = DateTime.now();
    final service = await pumpDiary(tester, today, entry: bothWrote(today));
    // One button: mine.
    expect(find.byTooltip('고치기'), findsOneWidget);

    await tester.tap(find.byTooltip('고치기'));
    await tester.pumpAndSettle();
    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(dialogField).controller!.text, mine);
    await tester.enterText(dialogField, '일기 기능 테스트 좀 하겠습니다');
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('저장')),
    );
    await tester.pumpAndSettle();

    expect(service.saves, 1);
    expect(service.entry!.content, '$friendText일기 기능 테스트 좀 하겠습니다');
    expect(shownInDiary('하겠습니다'), isTrue);
    expect(shownInDiary(friendText), isTrue);
  });

  testWidgets('my own part can be taken out', (tester) async {
    final today = DateTime.now();
    final service = await pumpDiary(tester, today, entry: bothWrote(today));
    await tester.tap(find.byTooltip('고치기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();

    expect(service.entry!.content, friendText);
    expect(service.entry!.segments.single.uid, 'friend_a');
    expect(shownInDiary(mine), isFalse);
  });

  testWidgets('once the day is over, my part is fixed in place too', (
    tester,
  ) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await pumpDiary(tester, yesterday, entry: bothWrote(yesterday));
    expect(shownInDiary(mine), isTrue);
    expect(find.byTooltip('고치기'), findsNothing);
  });
}
