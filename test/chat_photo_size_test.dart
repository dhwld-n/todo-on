import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:todo_on/models/chat_message.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/screens/friend_chat_screen.dart';
import 'package:todo_on/widgets/chat_photo.dart';

/// A photo the size the app sends (long side 1080).
String _photo(int width, int height) =>
    base64Encode(img.encodeJpg(img.Image(width: width, height: height)));

// Each photo its own message id: the chat caches decoded photos by id.
Future<Size> _shownSize(WidgetTester tester, String id, String photo) async {
  // A wide desktop window, where the bubble alone would allow ~1000px.
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        firestoreServiceProvider.overrideWithValue(null),
        chatMessagesProvider.overrideWith(
          (ref, uid) => Stream.value([
            ChatMessage(
              id: id,
              senderUid: 'friend-uid',
              text: '',
              createdAt: DateTime(2026),
              imageBase64: photo,
            ),
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
  // Decoding the photo is real work in the engine.
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
  return tester.getSize(find.byType(Image));
}

void main() {
  testWidgets('a wide photo stays small in a wide window, shape kept', (
    tester,
  ) async {
    final size = await _shownSize(tester, 'wide', _photo(1080, 810));
    expect(size.width, moreOrLessEquals(kChatPhotoMaxWidth, epsilon: 1));
    expect(
      size.height,
      moreOrLessEquals(kChatPhotoMaxWidth * 810 / 1080, epsilon: 1),
    );
    expect(find.byType(ChatPhoto), findsOneWidget);
  });

  testWidgets('a tall photo is held to the height limit instead', (
    tester,
  ) async {
    final size = await _shownSize(tester, 'tall', _photo(540, 1080));
    expect(size.height, moreOrLessEquals(kChatPhotoMaxHeight, epsilon: 1));
    expect(size.width, moreOrLessEquals(kChatPhotoMaxHeight / 2, epsilon: 1));
  });
}
