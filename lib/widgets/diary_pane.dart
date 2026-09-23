import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/shared_diary_entry.dart';
import '../providers/providers.dart';

class DiaryPane extends ConsumerWidget {
  final DateTime date;

  const DiaryPane({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(diaryTabProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  DateFormat('yyyy년 M월 d일 EEEE', 'ko_KR').format(date),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFamily: 'GriunFromsol',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('내 일기'),
                    selected: tab == DiaryTab.private,
                    onSelected: (_) =>
                        ref.read(diaryTabProvider.notifier).state =
                            DiaryTab.private,
                  ),
                  ChoiceChip(
                    label: const Text('공유 일기'),
                    selected: tab == DiaryTab.shared,
                    onSelected: (_) =>
                        ref.read(diaryTabProvider.notifier).state =
                            DiaryTab.shared,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: tab == DiaryTab.private
                ? _PrivateDiaryEditor(date: date)
                : _SharedDiaryEditor(date: date),
          ),
        ],
      ),
    );
  }
}

class _PrivateDiaryEditor extends ConsumerStatefulWidget {
  final DateTime date;

  const _PrivateDiaryEditor({required this.date});

  @override
  ConsumerState<_PrivateDiaryEditor> createState() =>
      _PrivateDiaryEditorState();
}

class _PrivateDiaryEditorState extends ConsumerState<_PrivateDiaryEditor> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String? _loadedKey;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSave(String dateKey) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      ref
          .read(firestoreServiceProvider)
          ?.saveDiaryEntry(dateKey, _controller.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateKey = dateKeyFor(widget.date);
    final entryAsync = ref.watch(diaryEntryProvider(dateKey));

    return entryAsync.when(
      data: (entry) {
        if (_loadedKey != dateKey) {
          _loadedKey = dateKey;
          _controller.text = entry?.content ?? '';
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
        }
        return TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          style: const TextStyle(fontFamily: 'GriunFromsol', height: 1.5),
          decoration: const InputDecoration(hintText: '오늘 하루는 어땠나요?'),
          onChanged: (_) => _scheduleSave(dateKey),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
    );
  }
}

class _SharedDiaryEditor extends ConsumerWidget {
  final DateTime date;

  const _SharedDiaryEditor({required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(followingProvider);
    return followingAsync.when(
      data: (uids) {
        if (uids.isEmpty) {
          return Center(
            child: Text(
              '친구를 추가하면 함께 쓰는 일기를 만들 수 있어요.',
              style: TextStyle(color: Theme.of(context).disabledColor),
            ),
          );
        }
        final selected = ref.watch(sharedDiaryFriendProvider);
        final activeUid = uids.contains(selected) ? selected! : uids.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final friendUid in uids)
                  _FriendChip(
                    uid: friendUid,
                    selected: friendUid == activeUid,
                    onTap: () => ref
                        .read(sharedDiaryFriendProvider.notifier)
                        .state = friendUid,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _SharedDiaryBody(date: date, friendUid: activeUid),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
    );
  }
}

class _FriendChip extends ConsumerWidget {
  final String uid;
  final bool selected;
  final VoidCallback onTap;

  const _FriendChip({
    required this.uid,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(friendProfileProvider(uid)).value;
    final nickname = (profile?['nickname'] as String?)?.trim();
    final displayText = (nickname != null && nickname.isNotEmpty)
        ? nickname
        : uid.substring(0, 8);
    return ChoiceChip(
      label: Text(displayText),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _SharedDiaryBody extends ConsumerStatefulWidget {
  final DateTime date;
  final String friendUid;

  const _SharedDiaryBody({required this.date, required this.friendUid});

  @override
  ConsumerState<_SharedDiaryBody> createState() => _SharedDiaryBodyState();
}

class _SharedDiaryBodyState extends ConsumerState<_SharedDiaryBody> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  String? _loadedKey;
  String? _dateKey;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _editing) {
      _debounce?.cancel();
      _save();
      setState(() => _editing = false);
    }
  }

  void _save() {
    final dateKey = _dateKey;
    final myUid = ref.read(authStateProvider).value?.uid;
    if (dateKey == null || myUid == null) return;
    final oldSegments = ref
            .read(
              sharedDiaryEntryProvider((
                otherUid: widget.friendUid,
                dateKey: dateKey,
              )),
            )
            .value
            ?.segments ??
        const <DiarySegment>[];
    final newSegments = DiarySegment.update(
      oldSegments,
      myUid,
      _controller.text.length,
    );
    ref
        .read(firestoreServiceProvider)
        ?.saveSharedDiaryEntry(
          widget.friendUid,
          dateKey,
          _controller.text,
          newSegments,
        );
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _save);
  }

  @override
  Widget build(BuildContext context) {
    final dateKey = dateKeyFor(widget.date);
    _dateKey = dateKey;
    final entryKey = '${widget.friendUid}_$dateKey';
    final entryAsync = ref.watch(
      sharedDiaryEntryProvider((otherUid: widget.friendUid, dateKey: dateKey)),
    );
    final myUid = ref.watch(authStateProvider).value?.uid;
    final myNickname = _displayName(
      ref.watch(profileDocProvider).value,
      myUid ?? '',
    );
    final friendNickname = _displayName(
      ref.watch(friendProfileProvider(widget.friendUid)).value,
      widget.friendUid,
    );

    return entryAsync.when(
      data: (entry) {
        if (_loadedKey != entryKey) {
          _loadedKey = entryKey;
          _editing = false;
          _controller.text = entry?.content ?? '';
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
          if (entry != null &&
              entry.segments.isEmpty &&
              entry.content.isNotEmpty) {
            ref
                .read(firestoreServiceProvider)
                ?.seedLegacyDiarySegment(
                  widget.friendUid,
                  dateKey,
                  entry.content.length,
                );
          }
        }
        final showEditor = _editing || _controller.text.isEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: showEditor
                  ? TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: _editing,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontFamily: 'GriunFromsol',
                        height: 1.5,
                      ),
                      decoration: const InputDecoration(
                        hintText: '오늘 있었던 일을 함께 나눠보세요',
                      ),
                      onChanged: (_) => _scheduleSave(),
                    )
                  : GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        setState(() => _editing = true);
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _focusNode.requestFocus(),
                        );
                      },
                      child: SingleChildScrollView(
                        child: _AttributedDiaryText(
                          entry: entry!,
                          myUid: myUid,
                          myNickname: myNickname,
                          friendNickname: friendNickname,
                        ),
                      ),
                    ),
            ),
            if (entry != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '마지막 수정: ${entry.updatedBy == myUid ? '나' : '친구'} · '
                  '${DateFormat('a h:mm', 'ko_KR').format(entry.updatedAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).disabledColor,
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
    );
  }
}

String _displayName(Map<String, dynamic>? profile, String uid) {
  final nickname = (profile?['nickname'] as String?)?.trim();
  if (nickname != null && nickname.isNotEmpty) return nickname;
  return uid.length >= 8 ? uid.substring(0, 8) : uid;
}

/// Read-only rendering of the shared diary text with a "- 닉네임" marker
/// right after each contributor's block, tap-to-edit switches to the
/// plain TextField in the parent.
class _AttributedDiaryText extends StatelessWidget {
  final SharedDiaryEntry entry;
  final String? myUid;
  final String myNickname;
  final String friendNickname;

  const _AttributedDiaryText({
    required this.entry,
    required this.myUid,
    required this.myNickname,
    required this.friendNickname,
  });

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(fontFamily: 'GriunFromsol', height: 1.5);
    final markerStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).disabledColor,
      fontWeight: FontWeight.w700,
    );
    final spans = <InlineSpan>[];
    var start = 0;
    for (final segment in entry.segments) {
      final end = segment.upTo.clamp(0, entry.content.length);
      if (end <= start) continue;
      final chunk = entry.content.substring(start, end);
      start = end;
      if (chunk.isEmpty) continue;
      spans.add(TextSpan(text: chunk, style: baseStyle));
      // Empty uid marks a legacy segment seeded for pre-feature text with
      // no real author to attribute - leave it unmarked.
      if (segment.uid.isNotEmpty) {
        final nickname = segment.uid == myUid ? myNickname : friendNickname;
        final leadingNewline = chunk.endsWith('\n') ? '' : '\n';
        spans.add(
          TextSpan(text: '$leadingNewline- $nickname\n', style: markerStyle),
        );
      }
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: entry.content, style: baseStyle));
    }
    return Text.rich(TextSpan(children: spans));
  }
}
