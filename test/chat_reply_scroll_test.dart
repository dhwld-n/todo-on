import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:todo_on/models/chat_message.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/screens/friend_chat_screen.dart';

ChatMessage _message(int i, {String? text, String? imageBase64}) => ChatMessage(
  id: 'm$i',
  senderUid: 'friend',
  text: text ?? 'msg $i',
  imageBase64: imageBase64,
  createdAt: DateTime(2026, 1, 1, 0, i),
);

// Mixed heights like a real chat: a lazy list can only estimate its total
// length then.
final _textMessages = [
  for (var i = 0; i < 40; i++)
    _message(i, text: i % 3 == 1 ? 'long $i${'\n...' * 15}' : null),
];

Future<void> _openChat(
  WidgetTester tester, [
  List<ChatMessage>? messages,
]) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        firestoreServiceProvider.overrideWithValue(null),
        chatMessagesProvider.overrideWith(
          (ref, uid) => Stream.value(messages ?? _textMessages),
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
}

Future<void> _reply(WidgetTester tester, String text) async {
  await tester.tap(find.text(text), buttons: 2); // right-click
  await tester.pumpAndSettle();
  await tester.tap(find.text('답장'));
  await tester.pumpAndSettle();
  // Bubble + reply preview bar.
  expect(find.text(text), findsNWidgets(2));
}

String _closestToListCenter(WidgetTester tester, Iterable<String> texts) {
  final center = tester.getRect(find.byType(ListView)).center.dy;
  double distance(String t) => (tester.getCenter(find.text(t)).dy - center).abs();
  return texts
      .where((t) => find.text(t).hitTestable().evaluate().isNotEmpty)
      .reduce((a, b) => distance(a) < distance(b) ? a : b);
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

    final target = _closestToListCenter(tester, [
      for (var i = 0; i < 40; i++) 'msg $i',
    ]);
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

  // Regression for v1.6.23: every rebuild re-decoded photo bubbles into new
  // image bytes, so photos briefly had zero height, the list's length
  // collapsed and choosing 답장 dragged the view to the bottom.
  testWidgets('choosing 답장 in a chat with photos leaves the chat in place', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final photo = base64Encode(img.encodePng(img.Image(width: 60, height: 40)));
    final messages = [
      for (var i = 0; i < 15; i++)
        _message(i, imageBase64: i % 3 == 1 ? photo : null),
    ];
    await _openChat(tester, messages);

    // Scroll through the whole chat so every photo gets built and decoded
    // (decoding is real async work in the engine, hence runAsync).
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    for (var i = 0; i <= 10; i++) {
      position.jumpTo(position.maxScrollExtent * i / 10);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }
    // Near the oldest messages, like the real report.
    position.jumpTo(position.maxScrollExtent * 0.9);
    await tester.pumpAndSettle();

    final target = _closestToListCenter(tester, [
      for (var i = 0; i < 15; i++)
        if (i % 3 != 1) 'msg $i',
    ]);
    final before = tester.getRect(find.text(target)).top;

    await _reply(tester, target);

    final after = tester.getRect(find.text(target).first).top;
    expect((after - before).abs(), lessThan(2));
  });
}
