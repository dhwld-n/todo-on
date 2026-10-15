import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../screens/friend_detail_screen.dart';
import '../services/firestore_service.dart';
import '../utils/display_name.dart';

/// How I add a friend: find them by ID/nickname, or swap friend codes.
enum AddFriendBy { search, code }

class FriendsPane extends ConsumerStatefulWidget {
  const FriendsPane({super.key});

  @override
  ConsumerState<FriendsPane> createState() => _FriendsPaneState();
}

class _FriendsPaneState extends ConsumerState<FriendsPane> {
  var _by = AddFriendBy.search;

  @override
  Widget build(BuildContext context) {
    final followingAsync = ref.watch(followingProvider);
    final myUid = ref.watch(authStateProvider).value?.uid ?? '';
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AddFriendBy>(
              segments: const [
                ButtonSegment(
                  value: AddFriendBy.search,
                  icon: Icon(Icons.search),
                  label: Text('검색'),
                ),
                ButtonSegment(
                  value: AddFriendBy.code,
                  icon: Icon(Icons.key_outlined),
                  label: Text('친구 코드'),
                ),
              ],
              selected: {_by},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _by = s.first),
            ),
          ),
          const SizedBox(height: 16),
          if (_by == AddFriendBy.search) ...[
            Text('내 아이디', style: titleStyle),
            const SizedBox(height: 8),
            const _MyHandleRow(),
            const SizedBox(height: 20),
            Text('친구 찾기', style: titleStyle),
            const SizedBox(height: 8),
            const _SearchPeople(),
          ] else ...[
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('친구 코드를 복사했어요')),
                    );
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
          ],
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

/// My ID, or a nudge to make one: without it nobody can find me by search.
class _MyHandleRow extends ConsumerWidget {
  const _MyHandleRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handle = ref.watch(profileDocProvider).value?['handle'] as String?;
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: handle != null
                ? Text('@$handle', style: const TextStyle(fontSize: 14))
                : Text(
                    '아이디를 만들면 친구가 검색으로 찾을 수 있어요',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).disabledColor,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => _HandleDialog(current: handle),
          ),
          child: Text(handle == null ? '만들기' : '바꾸기'),
        ),
      ],
    );
  }
}

class _HandleDialog extends ConsumerStatefulWidget {
  final String? current;

  const _HandleDialog({required this.current});

  @override
  ConsumerState<_HandleDialog> createState() => _HandleDialogState();
}

class _HandleDialogState extends ConsumerState<_HandleDialog> {
  late final _controller = TextEditingController(text: widget.current ?? '');
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final handle = normalizeHandle(_controller.text);
    if (handle == null) {
      setState(() => _error = '영어 소문자, 숫자, 점(.), 밑줄(_)로 3~20자');
      return;
    }
    if (handle == widget.current) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final nickname =
        (ref.read(profileDocProvider).value?['nickname'] as String?)?.trim() ??
        '';
    try {
      final ok =
          await ref
              .read(firestoreServiceProvider)
              ?.claimHandle(
                handle,
                oldHandle: widget.current,
                nickname: nickname,
              ) ??
          false;
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop();
      } else {
        setState(() => _error = '이미 누가 쓰고 있는 아이디예요');
      }
    } catch (_) {
      if (mounted) setState(() => _error = '저장하지 못했어요. 다시 해주세요');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('내 아이디'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          prefixText: '@',
          helperText: '다른 사람과 겹칠 수 없어요',
          errorText: _error,
        ),
        onSubmitted: (_) => _saving ? null : _save(),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _SearchPeople extends ConsumerStatefulWidget {
  const _SearchPeople();

  @override
  ConsumerState<_SearchPeople> createState() => _SearchPeopleState();
}

class _SearchPeopleState extends ConsumerState<_SearchPeople> {
  final _controller = TextEditingController();
  List<FoundPerson>? _found;
  bool _searching = false;
  final _adding = <String>{};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() => _searching = true);
    try {
      final found =
          await ref.read(firestoreServiceProvider)?.searchPeople(query) ??
          const <FoundPerson>[];
      if (mounted) setState(() => _found = found);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('검색하지 못했어요')));
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _add(FoundPerson person) async {
    setState(() => _adding.add(person.uid));
    try {
      await ref.read(firestoreServiceProvider)?.followUser(person.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_nameOf(person)}님을 친구로 추가했어요')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('추가에 실패했어요')));
      }
    } finally {
      if (mounted) setState(() => _adding.remove(person.uid));
    }
  }

  static String _nameOf(FoundPerson person) =>
      person.nickname.isEmpty ? '@${person.handle}' : person.nickname;

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(followingProvider).value ?? const <String>[];
    final found = _found;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: '아이디나 닉네임',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _searching ? null : _search(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _searching ? null : _search,
              child: _searching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('검색'),
            ),
          ],
        ),
        if (found != null && found.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '찾는 사람이 없어요. 아이디를 만든 사람만 검색돼요',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).disabledColor,
              ),
            ),
          ),
        if (found != null && found.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(top: 6),
              children: [
                for (final person in found)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: Text(_nameOf(person)),
                    subtitle: Text('@${person.handle}'),
                    trailing: friends.contains(person.uid)
                        ? const Text('친구')
                        : FilledButton.tonal(
                            onPressed: _adding.contains(person.uid)
                                ? null
                                : () => _add(person),
                            child: const Text('추가'),
                          ),
                  ),
              ],
            ),
          ),
      ],
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
    final displayText = displayNameFor(profile, uid);
    final bio = (profile?['bio'] as String?)?.trim();
    final photoBase64 = profile?['photoBase64'] as String?;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
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
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => FriendDetailScreen(uid: uid))),
      ),
    );
  }
}
