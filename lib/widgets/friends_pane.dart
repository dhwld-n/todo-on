import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../screens/friend_detail_screen.dart';

class FriendsPane extends ConsumerWidget {
  const FriendsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(followingProvider);
    final myUid = ref.watch(authStateProvider).value?.uid ?? '';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '내 친구 코드',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    myUid,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy_outlined),
                tooltip: '코드 복사',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: myUid));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('친구 코드를 복사했어요')));
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '코드로 친구 추가',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _AddFriendRow(myUid: myUid),
          const SizedBox(height: 20),
          Text(
            '내 친구',
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
                      '아직 추가한 친구가 없어요.',
                      style: TextStyle(color: Theme.of(context).disabledColor),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: uids.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _FriendTile(uid: uids[index]),
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

class _AddFriendRow extends ConsumerStatefulWidget {
  final String myUid;

  const _AddFriendRow({required this.myUid});

  @override
  ConsumerState<_AddFriendRow> createState() => _AddFriendRowState();
}

class _AddFriendRowState extends ConsumerState<_AddFriendRow> {
  final _controller = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    if (code == widget.myUid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('자기 자신은 추가할 수 없어요')));
      return;
    }
    setState(() => _adding = true);
    try {
      await ref.read(firestoreServiceProvider)?.followUser(code);
      _controller.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('친구를 추가했어요')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('추가에 실패했어요. 코드를 확인해주세요')));
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: '친구의 코드를 붙여넣으세요',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _adding ? null : _add(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _adding ? null : _add,
          child: _adding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('추가'),
        ),
      ],
    );
  }
}

class _FriendTile extends ConsumerWidget {
  final String uid;

  const _FriendTile({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(friendProfileProvider(uid));
    final profile = profileAsync.value;
    final nickname = (profile?['nickname'] as String?)?.trim();
    final displayText = (nickname != null && nickname.isNotEmpty)
        ? nickname
        : uid.substring(0, 8);
    final bio = (profile?['bio'] as String?)?.trim();
    final photoBase64 = profile?['photoBase64'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
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
        title: Text(displayText),
        subtitle: (bio != null && bio.isNotEmpty)
            ? Text(bio, maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.person_remove_outlined, size: 18),
          tooltip: '친구 삭제',
          onPressed: () =>
              ref.read(firestoreServiceProvider)?.unfollowUser(uid),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FriendDetailScreen(uid: uid)),
        ),
      ),
    );
  }
}

