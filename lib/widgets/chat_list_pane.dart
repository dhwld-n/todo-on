import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../models/group_chat.dart';
import '../providers/providers.dart';
import '../screens/friend_chat_screen.dart';
import '../screens/group_chat_screen.dart';

class ChatListPane extends ConsumerWidget {
  const ChatListPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(followingProvider);
    final groupsAsync = ref.watch(myGroupChatsProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '채팅',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.group_add_outlined),
                tooltip: '단톡방 만들기',
                visualDensity: VisualDensity.compact,
                onPressed: () => _showCreateGroupSheet(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: followingAsync.when(
              data: (uids) => groupsAsync.when(
                data: (groups) {
                  if (uids.isEmpty && groups.isEmpty) {
                    return Center(
                      child: Text(
                        '친구를 먼저 추가해주세요.',
                        style: TextStyle(
                          color: Theme.of(context).disabledColor,
                        ),
                      ),
                    );
                  }
                  final tiles = _sortByRecency(ref, uids, groups);
                  return ListView.separated(
                    itemCount: tiles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => tiles[index],
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('오류: $e')),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Newest last message first; chats with no messages yet sink to the
/// bottom in their original order.
List<Widget> _sortByRecency(
  WidgetRef ref,
  List<String> uids,
  List<GroupChat> groups,
) {
  final withTime = <MapEntry<Widget, DateTime?>>[
    for (final uid in uids)
      MapEntry(
        _ChatFriendTile(uid: uid),
        ref.watch(chatMessagesProvider(uid)).value?.lastOrNull?.createdAt,
      ),
    for (final group in groups)
      MapEntry(
        _GroupChatTile(group: group),
        ref.watch(groupMessagesProvider(group.id)).value?.lastOrNull?.createdAt,
      ),
  ];
  withTime.sort((a, b) {
    if (a.value == null || b.value == null) {
      return a.value == null ? (b.value == null ? 0 : 1) : -1;
    }
    return b.value!.compareTo(a.value!);
  });
  return [for (final e in withTime) e.key];
}

Future<void> _showCreateGroupSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _CreateGroupSheet(),
  );
}

class _CreateGroupSheet extends ConsumerStatefulWidget {
  const _CreateGroupSheet();

  @override
  ConsumerState<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<_CreateGroupSheet> {
  final _nameController = TextEditingController();
  final _selected = <String>{};
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_selected.length < 2 || _creating) return;
    setState(() => _creating = true);
    final groupId = await ref
        .read(firestoreServiceProvider)
        ?.createGroupChat(
          memberUids: _selected.toList(),
          name: _nameController.text.trim().isEmpty
              ? null
              : _nameController.text.trim(),
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    if (groupId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GroupChatScreen(
            group: GroupChat(
              id: groupId,
              name: _nameController.text.trim().isEmpty
                  ? null
                  : _nameController.text.trim(),
              members: [
                ref.read(authStateProvider).value?.uid ?? '',
                ..._selected,
              ],
              createdBy: ref.read(authStateProvider).value?.uid ?? '',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final followingAsync = ref.watch(followingProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '단톡방 만들기',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '방 이름 (선택)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '2명 이상 선택해주세요.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).disabledColor,
              ),
            ),
            Flexible(
              child: followingAsync.when(
                data: (uids) {
                  if (uids.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        '친구를 먼저 추가해주세요.',
                        style: TextStyle(
                          color: Theme.of(context).disabledColor,
                        ),
                      ),
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final uid in uids)
                        _MemberCheckboxTile(
                          uid: uid,
                          selected: _selected.contains(uid),
                          onChanged: (v) => setState(() {
                            if (v) {
                              _selected.add(uid);
                            } else {
                              _selected.remove(uid);
                            }
                          }),
                        ),
                    ],
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('오류: $e'),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _selected.length < 2 || _creating ? null : _create,
              child: _creating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('만들기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberCheckboxTile extends ConsumerWidget {
  final String uid;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _MemberCheckboxTile({
    required this.uid,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(friendProfileProvider(uid)).value;
    final nickname = (profile?['nickname'] as String?)?.trim();
    final displayText = (nickname != null && nickname.isNotEmpty)
        ? nickname
        : uid.substring(0, 8);
    return CheckboxListTile(
      value: selected,
      onChanged: (v) => onChanged(v ?? false),
      title: Text(displayText),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
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

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
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
                    (lastMessage.imageBase64 != null
                        ? '사진을 보냈어요'
                        : lastMessage.text),
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

class _GroupChatTile extends ConsumerWidget {
  final GroupChat group;

  const _GroupChatTile({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(authStateProvider).value?.uid ?? '';
    final otherMembers = group.members.where((m) => m != myUid).toList();
    final name = group.name?.trim();
    final displayText = (name != null && name.isNotEmpty)
        ? name
        : otherMembers
              .map((uid) {
                final profile = ref.watch(friendProfileProvider(uid)).value;
                final nickname = (profile?['nickname'] as String?)?.trim();
                return (nickname != null && nickname.isNotEmpty)
                    ? nickname
                    : uid.substring(0, 8);
              })
              .join(', ');

    final messages =
        ref.watch(groupMessagesProvider(group.id)).value ??
        const <ChatMessage>[];
    final lastRead = ref.watch(groupLastReadProvider(group.id)).value?[myUid];
    final lastMessage = messages.isEmpty ? null : messages.last;
    final unreadCount = messages
        .where(
          (m) =>
              m.senderUid != myUid &&
              (lastRead == null || m.createdAt.isAfter(lastRead)),
        )
        .length;

    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: colorScheme.secondary,
          child: const Icon(Icons.groups, color: Colors.white),
        ),
        title: Text(
          displayText,
          overflow: TextOverflow.ellipsis,
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
                    (lastMessage.imageBase64 != null
                        ? '사진을 보냈어요'
                        : lastMessage.text),
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
          MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)),
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
