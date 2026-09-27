import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_on/models/chat_message.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/screens/friend_chat_screen.dart';

Future<void> _openChat(WidgetTester tester) async {
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
        chatMessagesProvider.overrideWith((ref, uid) => Stream.value(messages)),
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
}

Future<void> _reply(WidgetTester tester, String text) async {
  await tester.longPress(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text('답장'));
  await tester.pumpAndSettle();
  // Bubble + reply preview bar.
  expect(find.text(text), findsNWidgets(2));
}

void main() {
  testWidgets('opens on the newest message', (tester) async {
    await _openChat(tester);
    expect(find.text('msg 39').hitTestable(), findsOneWidget);
  });

  testWidgets('choosing 답장 on an older message leaves the chat in place', (
    tester,
  ) async {
    await _openChat(tester);
    await tester.timedDrag(
      find.byType(ListView),
      const Offset(0, 300),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();

    // Reply to whichever message sits closest to the middle of the list.
    final listCenter = tester.getRect(find.byType(ListView)).center.dy;
    final target = [
      for (var i = 0; i < 40; i++) 'msg $i',
    ].where((t) => find.text(t).hitTestable().evaluate().isNotEmpty).reduce(
      (a, b) =>
          (tester.getCenter(find.text(a)).dy - listCenter).abs() <
              (tester.getCenter(find.text(b)).dy - listCenter).abs()
          ? a
          : b,
    );
    final before = tester.getRect(find.text(target)).top;

    await _reply(tester, target);

    final after = tester.getRect(find.text(target).first).top;
    expect((after - before).abs(), lessThan(2));
  });

  testWidgets('choosing 답장 on the newest message keeps it above the bar', (
    tester,
  ) async {
    await _openChat(tester);
    await _reply(tester, 'msg 39');

    final list = tester.getRect(find.byType(ListView));
    final bubble = tester.getRect(find.text('msg 39').first);
    expect(bubble.top, greaterThanOrEqualTo(list.top));
    expect(bubble.bottom, lessThanOrEqualTo(list.bottom));
  });
}
