import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_on/models/chat_message.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/screens/friend_chat_screen.dart';

// With no signed-in user the screen's own uid is '', so senderUid '' is "me".
Future<void> _openChat(WidgetTester tester, DateTime? friendLastRead) async {
  final messages = [
    for (var i = 0; i < 6; i++)
      ChatMessage(
        id: 'm$i',
        senderUid: i == 1 ? 'friend' : '',
        text: 'msg $i',
        createdAt: DateTime(2026, 1, 1, 0, i),
      ),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        firestoreServiceProvider.overrideWithValue(null),
        chatMessagesProvider.overrideWith((ref, uid) => Stream.value(messages)),
        chatFriendLastReadProvider.overrideWith(
          (ref, uid) => Stream.value(friendLastRead),
        ),
        friendProfileProvider.overrideWith((ref, uid) => Stream.value(null)),
      ],
      child: const MaterialApp(home: FriendChatScreen(uid: 'friend-uid')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('only my latest message says 안읽음, not every unread one', (
    tester,
  ) async {
    // Friend read up to msg 2; my msgs 3, 4, 5 are still unread.
    await _openChat(tester, DateTime(2026, 1, 1, 0, 2));
    expect(find.text('안읽음'), findsOneWidget);
    expect(find.text('읽음'), findsNothing);
  });

  testWidgets('never read: only my latest message says 안읽음', (tester) async {
    await _openChat(tester, null);
    expect(find.text('안읽음'), findsOneWidget);
  });

  testWidgets('all read: only my latest message says 읽음', (tester) async {
    await _openChat(tester, DateTime(2026, 1, 1, 0, 30));
    expect(find.text('읽음'), findsOneWidget);
    expect(find.text('안읽음'), findsNothing);
  });
}
