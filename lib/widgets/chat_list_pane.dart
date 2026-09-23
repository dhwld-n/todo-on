import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../providers/providers.dart';
import '../screens/friend_chat_screen.dart';

class ChatListPane extends ConsumerWidget {
  const ChatListPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(followingProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '채팅',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: followingAsync.when(
              data: (uids) {
                if (uids.isEmpty) {
                  return Center(
                    child: Text(
                      '친구를 먼저 추가해주세요.',
                      style: TextStyle(color: Theme.of(context).disabledColor),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: uids.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _ChatFriendTile(uid: uids[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatFriendTile extends ConsumerWidget {
  final String uid;

  const _ChatFriendTile({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(friendProfileProvider(uid));
    final profile = profileAsync.value;
    final nickname = (profile?['nickname'] as String?)?.trim();
    final displayText = (nickname != null && nickname.isNotEmpty)
        ? nickname
        : uid.substring(0, 8);
    final photoBase64 = profile?['photoBase64'] as String?;

    final myUid = ref.watch(authStateProvider).value?.uid ?? '';
    final messages = ref.watch(chatMessagesProvider(uid)).value ?? const <ChatMessage>[];
    final lastRead = ref.watch(chatLastReadProvider(uid)).value;
    final lastMessage = messages.isEmpty ? null : messages.last;
    final unreadCount = messages
        .where(
          (m) =>
              m.senderUid != myUid &&
              (lastRead == null || m.createdAt.isAfter(lastRead)),
        )
        .length;

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: colorScheme.primary,
          backgroundImage: photoBase64 != null
              ? MemoryImage(base64Decode(photoBase64))
              : null,
          child: photoBase64 == null
              ? Text(
                  displayText.isNotEmpty ? displayText[0] : '?',
                  style: const TextStyle(color: Colors.white),
                )
              : null,
        ),
        title: Text(
          displayText,
          style: TextStyle(
            fontWeight: unreadCount > 0 ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        subtitle: Text(
          unreadCount > 0
              ? '새 메시지 $unreadCount개'
              : lastMessage == null
              ? '대화를 시작해보세요'
              : (lastMessage.senderUid == myUid ? '나: ' : '') +
                    lastMessage.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: unreadCount > 0
                ? colorScheme.primary
                : Theme.of(context).disabledColor,
            fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (lastMessage != null)
              Text(
                _relativeTime(lastMessage.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).disabledColor,
                ),
              ),
            if (unreadCount > 0) ...[
              const SizedBox(height: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FriendChatScreen(uid: uid)),
        ),
      ),
    );
  }
}

String _relativeTime(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분';
  if (diff.inHours < 24) return '${diff.inHours}시간';
  if (diff.inDays < 7) return '${diff.inDays}일';
  return '${dateTime.month}/${dateTime.day}';
}
