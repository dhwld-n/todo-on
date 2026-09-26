import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_on/models/chat_message.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/screens/friend_chat_screen.dart';

void main() {
  testWidgets('choosing 답장 keeps the chat scrolled where it was', (
    tester,
  ) async {
    final messages = [
      for (var i = 0; i < 40; i++)
        ChatMessage(
          id: 'm$i',
          senderUid: 'friend',
          text: 'msg $i',
          createdAt: DateTime(2026, 1, 1, 0, i),
        ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          firestoreServiceProvider.overrideWithValue(null),
          chatMessagesProvider.overrideWith(
            (ref, uid) => Stream.value(messages),
          ),
          chatFriendLastReadProvider.overrideWith(
            (ref, uid) => Stream.value(null),
          ),
          friendProfileProvider.overrideWith(
            (ref, uid) => Stream.value({'nickname': '친구'}),
          ),
        ],
        child: const MaterialApp(home: FriendChatScreen(uid: 'friend-uid')),
      ),
    );
    await tester.pumpAndSettle();

    // Newest message is visible on open.
    expect(find.text('msg 39'), findsOneWidget);

    // Scroll up to an older message and reply to it.
    await tester.dragUntilVisible(
      find.text('msg 25'),
      find.byType(ListView),
      const Offset(0, 200),
    );
    await tester.pumpAndSettle();
    final before = tester.getCenter(find.text('msg 25')).dy;

    await tester.longPress(find.text('msg 25'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('답장'));
    await tester.pumpAndSettle();

    // Bubble + reply preview bar.
    expect(find.text('msg 25'), findsNWidgets(2));
    final after = tester.getCenter(find.text('msg 25').first).dy;
    expect((after - before).abs(), lessThan(80));
  });
}
