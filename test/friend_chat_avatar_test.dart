import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_on/models/chat_message.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/screens/friend_chat_screen.dart';

void main() {
  testWidgets(
    'the friend\'s picture and name head each run of their messages',
    (tester) async {
      var minute = 0;
      // No signed-in user in tests, so '' is "me".
      ChatMessage msg(String sender, String text) => ChatMessage(
        id: 'm$minute',
        senderUid: sender,
        text: text,
        createdAt: DateTime(2026, 1, 1, 0, minute++),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            firestoreServiceProvider.overrideWithValue(null),
            chatMessagesProvider.overrideWith(
              (ref, uid) => Stream.value([
                msg('friend-uid', 'f1'),
                msg('friend-uid', 'f2'),
                msg('', 'me1'),
                msg('friend-uid', 'f3'),
              ]),
            ),
            chatFriendLastReadProvider.overrideWith(
              (ref, uid) => Stream.value(null),
            ),
            friendProfileProvider.overrideWith(
              (ref, uid) => Stream.value({'nickname': '가람'}),
            ),
          ],
          child: const MaterialApp(home: FriendChatScreen(uid: 'friend-uid')),
        ),
      );
      await tester.pumpAndSettle();

      // Two runs of the friend's messages (f1-f2, f3); none for mine.
      expect(find.byType(CircleAvatar), findsNWidgets(2));
      // Name on each run's first bubble (the app bar title is the third).
      expect(find.text('가람'), findsNWidgets(3));

      final f1 = tester.getRect(find.text('f1'));
      // The list is built newest-first, so the first run's avatar is last.
      final avatarOfFirstRun = tester.getRect(find.byType(CircleAvatar).last);
      expect(avatarOfFirstRun.right, lessThan(f1.left));
      expect(tester.getRect(find.text('f2')).left, moreOrLessEquals(f1.left));
      // My own bubble stays on the right, no avatar beside it.
      expect(
        tester.getRect(find.text('me1')).center.dx,
        greaterThan(tester.getRect(find.text('f1')).center.dx),
      );
    },
  );
}
