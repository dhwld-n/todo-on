import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_on/models/shared_diary_entry.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/widgets/diary_pane.dart';

void main() {
  testWidgets('a dot marks friends whose shared diary edit I have not seen', (
    tester,
  ) async {
    await initializeDateFormatting('ko_KR');
    final editedAt = DateTime(2026, 9, 27, 21);
    // With no signed-in user, "me" is ''.
    final entries = {
      // Friend edited, I never looked: dot.
      'friend_a': SharedDiaryEntry(
        dateKey: '2026-09-27',
        content: 'a wrote',
        updatedAt: editedAt,
        updatedBy: 'friend_a',
      ),
      // Friend edited, I already saw that exact edit: no dot.
      'friend_b': SharedDiaryEntry(
        dateKey: '2026-09-27',
        content: 'b wrote',
        updatedAt: editedAt,
        updatedBy: 'friend_b',
        seenAt: {'': editedAt},
      ),
      // Friend edited again after I last looked: dot.
      'friend_c': SharedDiaryEntry(
        dateKey: '2026-09-27',
        content: 'c wrote more',
        updatedAt: editedAt,
        updatedBy: 'friend_c',
        seenAt: {'': editedAt.subtract(const Duration(minutes: 5))},
      ),
      // I was the last to edit: no dot.
      'friend_d': SharedDiaryEntry(
        dateKey: '2026-09-27',
        content: 'I wrote',
        updatedAt: editedAt,
        updatedBy: '',
      ),
      // Nothing written that day: no dot.
      'friend_e': null,
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          firestoreServiceProvider.overrideWithValue(null),
          diaryTabProvider.overrideWith((ref) => DiaryTab.shared),
          followingProvider.overrideWith(
            (ref) => Stream.value([
              'friend_b',
              'friend_a',
              'friend_c',
              'friend_d',
              'friend_e',
            ]),
          ),
          friendProfileProvider.overrideWith(
            (ref, uid) => Stream.value({'nickname': uid}),
          ),
          sharedDiaryEntryProvider.overrideWith(
            (ref, key) => Stream.value(entries[key.otherUid]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: DiaryPane(date: DateTime(2026, 9, 27))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    bool dotOn(String name) => tester
        .widget<Badge>(
          find.ancestor(of: find.text(name), matching: find.byType(Badge)),
        )
        .isLabelVisible;

    expect(dotOn('friend_a'), isTrue);
    expect(dotOn('friend_b'), isFalse);
    expect(dotOn('friend_c'), isTrue);
    expect(dotOn('friend_d'), isFalse);
    expect(dotOn('friend_e'), isFalse);
  });
}
