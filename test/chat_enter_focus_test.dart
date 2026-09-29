import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_on/models/group_chat.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/screens/friend_chat_screen.dart';
import 'package:todo_on/screens/group_chat_screen.dart';

/// Enter sends and leaves the cursor in the box; with focus elsewhere,
/// Enter puts it back there.
Future<void> _expectEnterKeepsComposerFocused(WidgetTester tester) async {
  FocusNode composer() =>
      tester.widget<EditableText>(find.byType(EditableText)).focusNode;

  await tester.tap(find.byType(TextField));
  await tester.pump();
  await tester.enterText(find.byType(TextField), '안녕');
  await tester.testTextInput.receiveAction(TextInputAction.send);
  await tester.pumpAndSettle();
  expect(
    tester.widget<TextField>(find.byType(TextField)).controller!.text,
    isEmpty,
  );
  expect(composer().hasFocus, isTrue);

  composer().unfocus();
  await tester.pump();
  expect(composer().hasFocus, isFalse);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump();
  expect(composer().hasFocus, isTrue);
}

void main() {
  testWidgets('1:1 chat: Enter keeps the message box focused', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          firestoreServiceProvider.overrideWithValue(null),
          chatMessagesProvider.overrideWith(
            (ref, uid) => Stream.value(const []),
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
    await _expectEnterKeepsComposerFocused(tester);
  });

  testWidgets('group chat: Enter keeps the message box focused', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          firestoreServiceProvider.overrideWithValue(null),
          groupMessagesProvider.overrideWith(
            (ref, id) => Stream.value(const []),
          ),
          groupLastReadProvider.overrideWith(
            (ref, id) => Stream.value(const {}),
          ),
          friendProfileProvider.overrideWith(
            (ref, uid) => Stream.value({'nickname': uid}),
          ),
        ],
        child: const MaterialApp(
          home: GroupChatScreen(
            group: GroupChat(
              id: 'g',
              name: null,
              members: ['', 'friend_a'],
              createdBy: '',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _expectEnterKeepsComposerFocused(tester);
  });
}
