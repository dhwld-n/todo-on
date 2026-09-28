import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_on/models/diary_group.dart';
import 'package:todo_on/models/shared_diary_entry.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/widgets/diary_pane.dart';

// With no signed-in user the screen's own uid is '', so member '' is "me".
final _group = DiaryGroup(
  id: 'group1',
  name: null,
  members: const ['', 'friend_a', 'friend_b'],
  createdBy: '',
);

List<Override> _overrides({SharedDiaryEntry? groupEntry}) => [
  authStateProvider.overrideWith((ref) => Stream.value(null)),
  firestoreServiceProvider.overrideWithValue(null),
  diaryTabProvider.overrideWith((ref) => DiaryTab.shared),
  followingProvider.overrideWith(
    (ref) => Stream.value(['friend_a', 'friend_b']),
  ),
  friendProfileProvider.overrideWith(
    (ref, uid) => Stream.value({'nickname': uid.isEmpty ? '나' : uid}),
  ),
  unseenSharedDiaryDatesProvider.overrideWith(
    (ref, uid) => Stream.value(const <String>[]),
  ),
  sharedDiaryEntryProvider.overrideWith((ref, key) => Stream.value(null)),
  myDiaryGroupsProvider.overrideWith((ref) => Stream.value([_group])),
  unseenDiaryGroupDatesProvider.overrideWith(
    (ref, id) => Stream.value(const <String>[]),
  ),
  diaryGroupEntryProvider.overrideWith((ref, key) => Stream.value(groupEntry)),
];

Future<void> _openDiary(WidgetTester tester, {SharedDiaryEntry? groupEntry}) async {
  await initializeDateFormatting('ko_KR');
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(groupEntry: groupEntry),
      child: MaterialApp(
        home: Scaffold(body: DiaryPane(date: DateTime(2026, 9, 28))),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('diary group chip falls back to member names when unnamed', (
    tester,
  ) async {
    await _openDiary(tester);
    expect(find.text('friend_a, friend_b'), findsOneWidget);
  });

  testWidgets('selecting the group shows its entry, attributed per member', (
    tester,
  ) async {
    const content = 'AB';
    final entry = SharedDiaryEntry(
      dateKey: '2026-09-28',
      content: content,
      updatedAt: DateTime(2026, 9, 28, 10),
      updatedBy: 'friend_b',
      segments: const [
        DiarySegment(uid: 'friend_a', upTo: 1),
        DiarySegment(uid: 'friend_b', upTo: 2),
      ],
    );
    await _openDiary(tester, groupEntry: entry);

    await tester.tap(find.text('friend_a, friend_b'));
    await tester.pumpAndSettle();

    final bodyFinder = find.byWidgetPredicate(
      (w) =>
          w is RichText &&
          w.text.toPlainText().contains('- friend_a') &&
          w.text.toPlainText().contains('- friend_b'),
    );
    expect(bodyFinder, findsOneWidget);
  });

  testWidgets('create-diary-group sheet only allows creating with 2+ members', (
    tester,
  ) async {
    await _openDiary(tester);
    await tester.tap(find.byIcon(Icons.group_add_outlined));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '만들기'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byType(CheckboxListTile).at(0));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '만들기'))
          .onPressed,
      isNull,
      reason: 'still only 1 member selected',
    );

    await tester.tap(find.byType(CheckboxListTile).at(1));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '만들기'))
          .onPressed,
      isNotNull,
      reason: '2 members selected now',
    );
  });
}
