import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_on/models/shared_diary_entry.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/widgets/diary_pane.dart';

void main() {
  testWidgets('shared diary body fills the available width', (tester) async {
    await initializeDateFormatting('ko_KR');
    const following = ['friend_a', 'friend_b', 'friend_c', 'friend_d'];
    final entry = SharedDiaryEntry(
      dateKey: '2026-09-28',
      content: '아 덥다',
      updatedAt: DateTime(2026, 9, 28, 10),
      updatedBy: 'friend_a',
      segments: const [DiarySegment(uid: 'friend_a', upTo: 4)],
    );

    final overrides = <Override>[
      authStateProvider.overrideWith((ref) => Stream.value(null)),
      firestoreServiceProvider.overrideWithValue(null),
      diaryTabProvider.overrideWith((ref) => DiaryTab.shared),
      followingProvider.overrideWith((ref) => Stream.value(following)),
      friendProfileProvider.overrideWith(
        (ref, uid) => Stream.value({'nickname': uid}),
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
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 700,
              child: DiaryPane(date: DateTime(2026, 9, 28)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final paneWidth = tester.getSize(find.byType(DiaryPane)).width;
    final contentFinder = find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().contains('아 덥다'),
    );
    final richTextWidth = tester.getSize(contentFinder).width;

    // The diary text area should span (most of) the pane's width, not
    // shrink-wrap to a narrow column with blank space beside it.
    expect(richTextWidth, greaterThan(paneWidth * 0.8));
  });
}
