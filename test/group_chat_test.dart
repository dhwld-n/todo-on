import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:todo_on/models/chat_message.dart';
import 'package:todo_on/models/group_chat.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/screens/group_chat_screen.dart';
import 'package:todo_on/widgets/chat_list_pane.dart';

// With no signed-in user the screen's own uid is '', so senderUid '' is "me".
final _group = GroupChat(
  id: 'group1',
  name: null,
  members: const ['', 'friend_a', 'friend_b'],
  createdBy: '',
);

final _messages = [
  ChatMessage(
    id: 'm1',
    senderUid: 'friend_a',
    text: 'hi from a',
    createdAt: DateTime(2026, 1, 1, 0, 0),
  ),
  ChatMessage(
    id: 'm2',
    senderUid: 'friend_b',
    text: 'hi from b',
    createdAt: DateTime(2026, 1, 1, 0, 1),
  ),
  ChatMessage(
    id: 'm3',
    senderUid: '',
    text: 'hi from me',
    createdAt: DateTime(2026, 1, 1, 0, 2),
  ),
];

Future<void> _openGroup(
  WidgetTester tester,
  Map<String, DateTime> lastRead, {
  List<ChatMessage>? messages,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        firestoreServiceProvider.overrideWithValue(null),
        groupMessagesProvider.overrideWith(
          (ref, id) => Stream.value(messages ?? _messages),
        ),
        groupLastReadProvider.overrideWith((ref, id) => Stream.value(lastRead)),
        // Real Firebase uids are never empty, so the fallback-nickname path
        // (uid.substring(0, 8)) never sees ''; give it a nickname here too
        // so the test's own placeholder "me" uid doesn't hit that fallback.
        friendProfileProvider.overrideWith(
          (ref, uid) => Stream.value({'nickname': uid.isEmpty ? '나' : uid}),
        ),
      ],
      child: MaterialApp(home: GroupChatScreen(group: _group)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpChatList(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        firestoreServiceProvider.overrideWithValue(null),
        followingProvider.overrideWith(
          (ref) => Stream.value(['friend_a', 'friend_c']),
        ),
        friendProfileProvider.overrideWith(
          (ref, uid) => Stream.value({'nickname': uid}),
        ),
        chatMessagesProvider.overrideWith(
          (ref, uid) => Stream.value([
            ChatMessage(
              id: 'old',
              senderUid: 'friend_a',
              text: 'old msg',
              createdAt: DateTime(2020),
            ),
          ]),
        ),
        chatLastReadProvider.overrideWith((ref, uid) => Stream.value(null)),
        myGroupChatsProvider.overrideWith((ref) => Stream.value([_group])),
        groupMessagesProvider.overrideWith(
          (ref, id) => Stream.value([_messages.last]),
        ),
        groupLastReadProvider.overrideWith((ref, id) => Stream.value(const {})),
      ],
      child: const MaterialApp(home: Scaffold(body: ChatListPane())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the sender name above messages from others, not mine', (
    tester,
  ) async {
    await _openGroup(tester, {
      'friend_a': DateTime(2026, 1, 1, 1, 0),
      'friend_b': DateTime(2026, 1, 1, 1, 0),
    });
    expect(find.text('friend_a'), findsOneWidget);
    expect(find.text('friend_b'), findsOneWidget);
  });

  testWidgets('a run of messages from one person names them only once', (
    tester,
  ) async {
    var minute = 0;
    ChatMessage msg(String sender, String text) => ChatMessage(
      id: 'm$minute',
      senderUid: sender,
      text: text,
      createdAt: DateTime(2026, 1, 1, 0, minute++),
    );
    await _openGroup(
      tester,
      {},
      messages: [
        msg('friend_a', 'a1'),
        msg('friend_a', 'a2'),
        msg('friend_a', 'a3'),
        msg('friend_b', 'b1'),
        msg('friend_b', 'b2'),
        msg('friend_a', 'a4'),
      ],
    );
    // friend_a's first run and their later run; friend_b's single run.
    expect(find.text('friend_a'), findsNWidgets(2));
    expect(find.text('friend_b'), findsOneWidget);

    // A profile picture (here the initial, no photo set) beside each name,
    // sitting to the left of that first bubble.
    expect(find.byType(CircleAvatar), findsNWidgets(3));
    final avatar = tester.getRect(find.byType(CircleAvatar).first);
    final firstBubble = tester.getRect(find.text('a1'));
    expect(avatar.right, lessThan(firstBubble.left));
    // Later bubbles in a run stay lined up with the first one.
    expect(
      tester.getRect(find.text('a2')).left,
      moreOrLessEquals(firstBubble.left),
    );
  });

  testWidgets('a member with a profile photo shows it in the chat', (
    tester,
  ) async {
    final png = img.encodePng(img.Image(width: 4, height: 4));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          firestoreServiceProvider.overrideWithValue(null),
          groupMessagesProvider.overrideWith(
            (ref, id) => Stream.value(_messages),
          ),
          groupLastReadProvider.overrideWith((ref, id) => Stream.value({})),
          friendProfileProvider.overrideWith(
            (ref, uid) => Stream.value({
              'nickname': uid,
              if (uid == 'friend_a') 'photoBase64': base64Encode(png),
            }),
          ),
        ],
        child: MaterialApp(home: GroupChatScreen(group: _group)),
      ),
    );
    await tester.pumpAndSettle();
    // friend_a and friend_b get one each, not me.
    expect(find.byType(CircleAvatar), findsNWidgets(2));
    // Pick each avatar by the message it sits beside.
    CircleAvatar avatarBeside(String text) {
      final y = tester.getRect(find.text(text)).center.dy;
      return tester
          .widgetList<CircleAvatar>(find.byType(CircleAvatar))
          .firstWhere(
            (a) => (tester.getRect(find.byWidget(a)).center.dy - y).abs() < 40,
          );
    }

    expect(avatarBeside('hi from a').backgroundImage, isA<MemoryImage>());
    // friend_b has no photo: the initial instead.
    expect(avatarBeside('hi from b').backgroundImage, isNull);
  });

  testWidgets('my last message shows how many members have not read it', (
    tester,
  ) async {
    // friend_a has read up to now; friend_b has never read.
    await _openGroup(tester, {'friend_a': DateTime(2026, 1, 1, 1, 0)});
    expect(find.text('안읽음 1'), findsOneWidget);
  });

  testWidgets('shows 읽음 once every other member has read it', (tester) async {
    await _openGroup(tester, {
      'friend_a': DateTime(2026, 1, 1, 1, 0),
      'friend_b': DateTime(2026, 1, 1, 1, 0),
    });
    expect(find.text('읽음'), findsOneWidget);
    expect(find.textContaining('안읽음'), findsNothing);
  });

  testWidgets('group chat title falls back to member names when unnamed', (
    tester,
  ) async {
    await _openGroup(tester, {});
    expect(find.text('friend_a, friend_b'), findsOneWidget);
  });

  testWidgets('the people icon opens a drawer listing every member', (
    tester,
  ) async {
    await _openGroup(tester, {});
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('참여자 3명'), findsOneWidget);
    expect(find.text('friend_a'), findsWidgets);
    expect(find.text('friend_b'), findsWidgets);
    // My own uid ('') falls back to the empty-string prefix; just check the
    // "(나)" marker shows for exactly one member.
    expect(find.textContaining('(나)'), findsOneWidget);
    expect(find.text('나가기'), findsOneWidget);
  });

  testWidgets('group chat with the newest message is listed above the friend', (
    tester,
  ) async {
    await _pumpChatList(tester);
    final groupY = tester.getTopLeft(find.text('friend_a, friend_b')).dy;
    final friendY = tester.getTopLeft(find.text('friend_a').first).dy;
    expect(groupY, lessThan(friendY));
  });

  testWidgets('create-group sheet only allows creating with 2+ members', (
    tester,
  ) async {
    await _pumpChatList(tester);
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
