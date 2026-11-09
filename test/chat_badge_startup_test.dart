import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_on/models/chat_message.dart';
import 'package:todo_on/providers/providers.dart';

// At startup a chat's messages can arrive before its last-read time. The
// 채팅 badge must wait for both, not read "no last-read yet" as "never read"
// and flash on for a moment.
void main() {
  final message = ChatMessage(
    id: 'm1',
    senderUid: 'friend',
    text: 'hi',
    createdAt: DateTime(2026, 11, 9, 12),
  );

  Future<bool> unread(Stream<DateTime?> lastRead) async {
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        followingProvider.overrideWith((ref) => Stream.value(['friend'])),
        myGroupChatsProvider.overrideWith((ref) => Stream.value(const [])),
        chatMessagesProvider.overrideWith(
          (ref, uid) => Stream.value([message]),
        ),
        chatLastReadProvider.overrideWith((ref, uid) => lastRead),
      ],
    );
    addTearDown(container.dispose);
    container.listen(hasUnreadChatProvider, (_, _) {});
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return container.read(hasUnreadChatProvider);
  }

  test('no badge while the last-read time is still loading', () async {
    final pending = StreamController<DateTime?>();
    addTearDown(pending.close);
    expect(await unread(pending.stream), isFalse);
  });

  test('badge once it is known the chat was never read', () async {
    expect(await unread(Stream.value(null)), isTrue);
  });

  test('no badge when the message is older than the last read', () async {
    expect(await unread(Stream.value(DateTime(2026, 11, 9, 13))), isFalse);
  });

  test('badge when the message is newer than the last read', () async {
    expect(await unread(Stream.value(DateTime(2026, 11, 9, 11))), isTrue);
  });
}
