import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_on/models/group_chat.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/screens/friend_chat_screen.dart';
import 'package:todo_on/screens/group_chat_screen.dart';
import 'package:todo_on/utils/chat_enter.dart';

final _screens = <String, Widget>{
  '1:1': const FriendChatScreen(uid: 'friend-uid'),
  'group': const GroupChatScreen(
    group: GroupChat(
      id: 'g',
      name: null,
      members: ['', 'friend_a'],
      createdBy: '',
    ),
  ),
};

Future<void> _open(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        firestoreServiceProvider.overrideWithValue(null),
        chatMessagesProvider.overrideWith((ref, uid) => Stream.value(const [])),
        chatFriendLastReadProvider.overrideWith(
          (ref, uid) => Stream.value(null),
        ),
        groupMessagesProvider.overrideWith((ref, id) => Stream.value(const [])),
        groupLastReadProvider.overrideWith((ref, id) => Stream.value(const {})),
        friendProfileProvider.overrideWith(
          (ref, uid) => Stream.value({'nickname': uid}),
        ),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byType(TextField));
  await tester.pump();
}

String _composerText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

/// What the Windows engine sends on Enter in a multi-line box: the text
/// with a newline inserted at the caret.
Future<void> _engineEnter(WidgetTester tester, String before) async {
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: '$before\n',
      selection: TextSelection.collapsed(offset: before.length + 1),
    ),
  );
  await tester.pump();
}

void main() {
  group('bareEnterSubmission', () {
    test('a bare Enter at the end sends what was typed', () {
      expect(bareEnterSubmission('안녕', '안녕\n', 3, shiftPressed: false), '안녕');
    });
    test('Enter in the middle of the text still sends it all', () {
      expect(
        bareEnterSubmission('안녕하세요', '안녕\n하세요', 3, shiftPressed: false),
        '안녕하세요',
      );
    });
    test('Shift+Enter keeps the new line', () {
      expect(bareEnterSubmission('안녕', '안녕\n', 3, shiftPressed: true), isNull);
    });
    test('pasting several lines is not a send', () {
      expect(
        bareEnterSubmission('a', 'a\nb\nc', 5, shiftPressed: false),
        isNull,
      );
    });
    test('ordinary typing is not a send', () {
      expect(bareEnterSubmission('안', '안녕', 2, shiftPressed: false), isNull);
    });
  });

  for (final MapEntry(key: name, value: screen) in _screens.entries) {
    testWidgets(
      '$name chat on a computer: Shift+Enter adds a line, Enter sends',
      (tester) async {
        await _open(tester, screen);
        expect(tester.widget<TextField>(find.byType(TextField)).maxLines, 5);

        await tester.enterText(find.byType(TextField), '첫 줄');
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await _engineEnter(tester, '첫 줄');
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        expect(_composerText(tester), '첫 줄\n');

        await tester.enterText(find.byType(TextField), '첫 줄\n둘째 줄');
        await _engineEnter(tester, '첫 줄\n둘째 줄');
        // Sent: the box is empty again and still has the cursor.
        expect(_composerText(tester), isEmpty);
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          isTrue,
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    testWidgets(
      '$name chat on a phone keeps the keyboard send key',
      (tester) async {
        await _open(tester, screen);
        expect(
          tester.widget<TextField>(find.byType(TextField)).textInputAction,
          TextInputAction.send,
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}
