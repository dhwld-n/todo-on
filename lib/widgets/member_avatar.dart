import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../utils/display_name.dart';
import 'paper.dart';

// Profile photos are base64 in the profile doc; decode each one once so
// every bubble reuses the same bytes (and the image cache hits).
final _avatarBytes = <String, Uint8List>{};

const kChatAvatarSize = 36.0;

/// A member's profile picture, or their initial, in an inked circle.
class MemberAvatar extends ConsumerWidget {
  final String uid;

  const MemberAvatar({super.key, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(friendProfileProvider(uid)).value;
    final photo = profile?['photoBase64'] as String?;
    final name = displayNameFor(profile, uid);
    return InkAvatar(
      radius: kChatAvatarSize / 2 - 1.5,
      image: photo == null
          ? null
          : MemoryImage(
              _avatarBytes.putIfAbsent(photo, () => base64Decode(photo)),
            ),
      initial: name.isNotEmpty ? name[0] : '?',
    );
  }
}
