import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Largest a photo shows in a chat bubble, whatever the window's size; a
/// tap opens it full size.
const kChatPhotoMaxWidth = 260.0;
const kChatPhotoMaxHeight = 320.0;

/// A sent photo inside a chat bubble, scaled down to fit
/// [kChatPhotoMaxWidth] x [kChatPhotoMaxHeight] with its shape kept.
class ChatPhoto extends StatelessWidget {
  final Uint8List bytes;

  const ChatPhoto(this.bytes, {super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: kChatPhotoMaxWidth,
          maxHeight: kChatPhotoMaxHeight,
        ),
        child: Image.memory(bytes),
      ),
    );
  }
}
