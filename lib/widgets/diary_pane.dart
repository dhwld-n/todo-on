import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/diary_group.dart';
import '../models/shared_diary_entry.dart';
import '../providers/providers.dart';
import '../utils/display_name.dart';

class DiaryPane extends ConsumerWidget {
  final DateTime date;

  const DiaryPane({super.key, required this.date});

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    // Same range as the calendar.
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12, 31),
    );
    if (picked == null || !context.mounted) return;
    ref.read(selectedDateProvider.notifier).state = picked;
    ref.read(focusedMonthProvider.notifier).state = picked;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(diaryTabProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A Wrap, not a Row: on a phone the chips would leave the date
          // ~80px and wrap it over 4-5 lines, so it drops them to their own
          // line instead. Wide screens still fit both side by side (full
          // width so spaceBetween keeps the chips at the right edge).
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                // Tappable: on Android the calendar only lives in the TODO
                // tab, so this is the diary's own way to change the day.
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _pickDate(context, ref),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: DateFormat(
                            'yyyy년 M월 d일 EEEE ',
                            'ko_KR',
                          ).format(date),
                        ),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(
                            Icons.calendar_month_outlined,
                            size: 18,
                            color: Theme.of(context).disabledColor,
                          ),
                        ),
                      ],
                    ),
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
                      label: const Text('교환일기'),
                      selected: tab == DiaryTab.shared,
                      onSelected: (_) =>
                          ref.read(diaryTabProvider.notifier).state =
                              DiaryTab.shared,
                    ),
                  ],
                ),
              ],
            ),
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
    final groups =
        ref.watch(myDiaryGroupsProvider).value ?? const <DiaryGroup>[];
    return followingAsync.when(
      data: (uids) {
        if (uids.isEmpty && groups.isEmpty) {
          return Center(
            child: Text(
              '친구를 추가하면 함께 쓰는 일기를 만들 수 있어요.',
              style: TextStyle(color: Theme.of(context).disabledColor),
            ),
          );
        }
        final selectedGroupId = ref.watch(sharedDiaryGroupProvider);
        DiaryGroup? selectedGroup;
        for (final g in groups) {
          if (g.id == selectedGroupId) selectedGroup = g;
        }
        final selectedFriend = ref.watch(sharedDiaryFriendProvider);
        String? activeUid;
        if (selectedGroup == null) {
          if (uids.contains(selectedFriend)) {
            activeUid = selectedFriend;
          } else if (uids.isNotEmpty) {
            activeUid = uids.first;
          } else if (groups.isNotEmpty) {
            selectedGroup = groups.first;
          }
        }
        final unseenDates = selectedGroup != null
            ? ref
                      .watch(unseenDiaryGroupDatesProvider(selectedGroup.id))
                      .value ??
                  const <String>[]
            : ref.watch(unseenSharedDiaryDatesProvider(activeUid!)).value ??
                  const <String>[];
        // On a phone with the keyboard up, the friend chips (often several
        // rows) would squeeze the input down to nothing - hide them while
        // typing, nobody switches friends mid-sentence.
        final keyboardOpen = _keyboardOpen(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!keyboardOpen) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final friendUid in uids)
                          _FriendChip(
                            uid: friendUid,
                            selected:
                                selectedGroup == null && friendUid == activeUid,
                            onTap: () {
                              ref
                                      .read(sharedDiaryGroupProvider.notifier)
                                      .state =
                                  null;
                              ref
                                      .read(sharedDiaryFriendProvider.notifier)
                                      .state =
                                  friendUid;
                            },
                          ),
                        for (final group in groups)
                          _DiaryGroupChip(
                            group: group,
                            selected: selectedGroup?.id == group.id,
                            onTap: () =>
                                ref
                                        .read(sharedDiaryGroupProvider.notifier)
                                        .state =
                                    group.id,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.group_add_outlined),
                    tooltip: '교환일기 그룹 만들기',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _showCreateDiaryGroupSheet(context, ref),
                  ),
                ],
              ),
              _UnseenDates(
                unseenDates: unseenDates,
                currentDateKey: dateKeyFor(date),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: selectedGroup != null
                  ? _DiaryGroupBody(date: date, group: selectedGroup)
                  : _SharedDiaryBody(date: date, friendUid: activeUid!),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
    );
  }
}

Future<void> _showCreateDiaryGroupSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _CreateDiaryGroupSheet(),
  );
}

class _CreateDiaryGroupSheet extends ConsumerStatefulWidget {
  const _CreateDiaryGroupSheet();

  @override
  ConsumerState<_CreateDiaryGroupSheet> createState() =>
      _CreateDiaryGroupSheetState();
}

class _CreateDiaryGroupSheetState
    extends ConsumerState<_CreateDiaryGroupSheet> {
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
        ?.createDiaryGroup(
          memberUids: _selected.toList(),
          name: _nameController.text.trim().isEmpty
              ? null
              : _nameController.text.trim(),
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    if (groupId != null) {
      ref.read(sharedDiaryGroupProvider.notifier).state = groupId;
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
              '교환일기 그룹 만들기',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '그룹 이름 (선택)',
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
                        _DiaryGroupMemberCheckboxTile(
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
                loading: () => const Center(child: CircularProgressIndicator()),
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

class _DiaryGroupMemberCheckboxTile extends ConsumerWidget {
  final String uid;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _DiaryGroupMemberCheckboxTile({
    required this.uid,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(friendProfileProvider(uid)).value;
    return CheckboxListTile(
      value: selected,
      onChanged: (v) => onChanged(v ?? false),
      title: Text(displayNameFor(profile, uid)),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
    );
  }
}

class _DiaryGroupChip extends ConsumerWidget {
  final DiaryGroup group;
  final bool selected;
  final VoidCallback onTap;

  const _DiaryGroupChip({
    required this.group,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(authStateProvider).value?.uid ?? '';
    final label = (group.name?.trim().isNotEmpty ?? false)
        ? group.name!.trim()
        : group.members
              .where((m) => m != myUid)
              .map(
                (m) => displayNameFor(
                  ref.watch(friendProfileProvider(m)).value,
                  m,
                ),
              )
              .join(', ');
    final unseen = ref.watch(unseenDiaryGroupDatesProvider(group.id)).value;
    return Badge(
      smallSize: 9,
      isLabelVisible: unseen?.isNotEmpty ?? false,
      child: ChoiceChip(
        avatar: const Icon(Icons.groups, size: 16),
        label: Text(label.isEmpty ? '그룹' : label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
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
    final unseen = ref.watch(unseenSharedDiaryDatesProvider(uid)).value;
    return Badge(
      smallSize: 9,
      isLabelVisible: unseen?.isNotEmpty ?? false,
      child: ChoiceChip(
        label: Text(displayText),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

/// Other dates this friend or group wrote on that I haven't seen yet;
/// tapping one jumps the diary there (opening it marks it seen).
class _UnseenDates extends ConsumerWidget {
  final List<String> unseenDates;
  final String currentDateKey;

  const _UnseenDates({required this.unseenDates, required this.currentDateKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dates = [
      for (final key in unseenDates)
        if (key != currentDateKey) key,
    ];
    if (dates.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('다른 날 새로 쓴 내용:', style: Theme.of(context).textTheme.bodySmall),
          for (final key in dates)
            ActionChip(
              avatar: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  shape: BoxShape.circle,
                ),
              ),
              label: Text(DateFormat('M월 d일').format(DateTime.parse(key))),
              visualDensity: VisualDensity.compact,
              onPressed: () => ref.read(selectedDateProvider.notifier).state =
                  DateTime.parse(key),
            ),
        ],
      ),
    );
  }
}

/// Scaffold strips the keyboard inset out of the MediaQuery its body sees,
/// so read it straight off the view.
bool _keyboardOpen(BuildContext context) =>
    View.of(context).viewInsets.bottom > 0;

/// What [entry] becomes when [myUid] adds [typed] at its end, or null when
/// there's nothing to add. Each save is its own part, signed under it, and
/// nothing already saved changes - mine included.
(String, List<DiarySegment>)? appendToDiary(
  SharedDiaryEntry? entry,
  String typed,
  String myUid,
) {
  final text = typed.trim();
  if (text.isEmpty) return null;
  final before = entry?.content ?? '';
  final content = before + text;
  return (
    content,
    [
      ...?entry?.segments,
      // Text from before per-author parts existed stays unsigned.
      if (before.isNotEmpty && (entry?.segments.isEmpty ?? true))
        DiarySegment(uid: '', upTo: before.length),
      DiarySegment(uid: myUid, upTo: content.length),
    ],
  );
}

/// [entry] with its part at [index] rewritten to [text], or taken out when
/// [text] is blank. The parts after it keep their own text; only where they
/// start moves.
(String, List<DiarySegment>) replaceDiaryPart(
  SharedDiaryEntry entry,
  int index,
  String text,
) {
  final segments = entry.segments;
  final start = index == 0
      ? 0
      : segments[index - 1].upTo.clamp(0, entry.content.length);
  final end = segments[index].upTo.clamp(start, entry.content.length);
  final replacement = text.trim();
  final shift = replacement.length - (end - start);
  final content =
      entry.content.substring(0, start) +
      replacement +
      entry.content.substring(end);
  return (
    content,
    [
      for (var i = 0; i < segments.length; i++)
        if (i < index)
          segments[i]
        else if (i > index)
          DiarySegment(uid: segments[i].uid, upTo: segments[i].upTo + shift)
        else if (replacement.isNotEmpty)
          DiarySegment(uid: segments[i].uid, upTo: end + shift),
    ],
  );
}

class _SharedDiaryBody extends ConsumerWidget {
  final DateTime date;
  final String friendUid;

  const _SharedDiaryBody({required this.date, required this.friendUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateKey = dateKeyFor(date);
    final entryAsync = ref.watch(
      sharedDiaryEntryProvider((otherUid: friendUid, dateKey: dateKey)),
    );
    final myUid = ref.watch(authStateProvider).value?.uid;
    final myNickname = displayNameFor(
      ref.watch(profileDocProvider).value,
      myUid ?? '',
    );
    final friendNickname = displayNameFor(
      ref.watch(friendProfileProvider(friendUid)).value,
      friendUid,
    );

    return entryAsync.when(
      data: (entry) {
        if (entry != null && myUid != null && entry.hasUnseenEditFor(myUid)) {
          // Open on screen = seen; clears the dot on this friend's chip.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(firestoreServiceProvider)
                ?.markSharedDiarySeen(friendUid, dateKey, entry.updatedAt);
          });
        }
        return _DiaryThread(
          key: ValueKey('${friendUid}_$dateKey'),
          entry: entry,
          myUid: myUid,
          nicknameFor: (uid) => uid == myUid ? myNickname : friendNickname,
          onSave: (content, segments) async => ref
              .read(firestoreServiceProvider)
              ?.saveSharedDiaryEntry(friendUid, dateKey, content, segments),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
    );
  }
}

/// Same as [_SharedDiaryBody] but for a multi-member [DiaryGroup]: the
/// entry is written the same way, only by more people.
class _DiaryGroupBody extends ConsumerWidget {
  final DateTime date;
  final DiaryGroup group;

  const _DiaryGroupBody({required this.date, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateKey = dateKeyFor(date);
    final entryAsync = ref.watch(
      diaryGroupEntryProvider((groupId: group.id, dateKey: dateKey)),
    );
    final myUid = ref.watch(authStateProvider).value?.uid;
    final myNickname = displayNameFor(
      ref.watch(profileDocProvider).value,
      myUid ?? '',
    );
    String nicknameFor(String uid) => uid == myUid
        ? myNickname
        : displayNameFor(ref.watch(friendProfileProvider(uid)).value, uid);

    return entryAsync.when(
      data: (entry) {
        if (entry != null && myUid != null && entry.hasUnseenEditFor(myUid)) {
          // Open on screen = seen; clears the dot on this group's chip.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(firestoreServiceProvider)
                ?.markDiaryGroupSeen(group.id, dateKey, entry.updatedAt);
          });
        }
        return _DiaryThread(
          key: ValueKey('${group.id}_$dateKey'),
          entry: entry,
          myUid: myUid,
          nicknameFor: nicknameFor,
          onSave: (content, segments) async => ref
              .read(firestoreServiceProvider)
              ?.saveDiaryGroupEntry(group.id, dateKey, content, segments),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
    );
  }
}

/// A shared day's diary: everything saved so far, read-only and signed by
/// whoever wrote each part, over an empty box for adding the next part.
/// Saving moves what's typed up into the diary and empties the box.
class _DiaryThread extends StatefulWidget {
  final SharedDiaryEntry? entry;
  final String? myUid;
  final String Function(String uid) nicknameFor;
  final Future<void> Function(String content, List<DiarySegment> segments)
  onSave;

  const _DiaryThread({
    super.key,
    required this.entry,
    required this.myUid,
    required this.nicknameFor,
    required this.onSave,
  });

  @override
  State<_DiaryThread> createState() => _DiaryThreadState();
}

class _DiaryThreadState extends State<_DiaryThread> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  var _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Saves a whole new entry, telling the person if it didn't go through.
  Future<bool> _write(String content, List<DiarySegment> segments) async {
    try {
      await widget.onSave(content, segments);
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('저장하지 못했어요. 다시 눌러주세요')));
      }
      return false;
    }
  }

  /// Fixes or takes out one of my own parts.
  Future<void> _editPart(int index) async {
    final entry = widget.entry;
    if (entry == null) return;
    final start = index == 0 ? 0 : entry.segments[index - 1].upTo;
    final original = entry.content.substring(
      start.clamp(0, entry.content.length),
      entry.segments[index].upTo.clamp(start, entry.content.length),
    );
    // Not disposed here: the dialog's closing animation still reads it.
    final controller = TextEditingController(text: original);
    final edited = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('내가 쓴 글 고치기'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(fontFamily: 'GriunFromsol', height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('지우기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    final latest = widget.entry;
    if (edited == null || latest == null || edited.trim() == original.trim()) {
      return;
    }
    final (content, segments) = replaceDiaryPart(latest, index, edited);
    await _write(content, segments);
  }

  Future<void> _save() async {
    final myUid = widget.myUid;
    if (_saving || myUid == null) return;
    final typed = _controller.text;
    final result = appendToDiary(widget.entry, typed, myUid);
    if (result == null) return;
    setState(() => _saving = true);
    // Emptied right away, the way a chat message leaves the box on send.
    _controller.clear();
    final saved = await _write(result.$1, result.$2);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) {
      // Didn't go through: hand the writing back rather than lose it.
      if (_controller.text.isEmpty) _controller.text = typed;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Theme.of(context).disabledColor);
    final lastBy = entry == null
        ? ''
        : entry.updatedBy == widget.myUid
        ? '나'
        : widget.nicknameFor(entry.updatedBy);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: entry == null || entry.content.isEmpty
              ? Center(child: Text('아직 아무도 안 썼어요', style: muted))
              : SingleChildScrollView(
                  controller: _scroll,
                  child: _AttributedDiaryText(
                    entry: entry,
                    nicknameFor: widget.nicknameFor,
                    // Only my own parts, on any day.
                    editableUid: widget.myUid,
                    onEditPart: _editPart,
                  ),
                ),
        ),
        if (entry != null && entry.content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '마지막 수정: $lastBy · '
              '${DateFormat('a h:mm', 'ko_KR').format(entry.updatedAt)}',
              style: muted,
            ),
          ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontFamily: 'GriunFromsol', height: 1.5),
                decoration: const InputDecoration(
                  hintText: '오늘 있었던 일을 함께 나눠보세요',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('저장'),
            ),
          ],
        ),
      ],
    );
  }
}

/// The shared diary text, one block per part with a "- 닉네임" line under
/// it. Parts by [editableUid] get a button there to fix them.
class _AttributedDiaryText extends StatelessWidget {
  final SharedDiaryEntry entry;
  final String Function(String uid) nicknameFor;
  final String? editableUid;
  final void Function(int index)? onEditPart;

  const _AttributedDiaryText({
    required this.entry,
    required this.nicknameFor,
    this.editableUid,
    this.onEditPart,
  });

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(fontFamily: 'GriunFromsol', height: 1.5);
    final markerStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).disabledColor,
      fontWeight: FontWeight.w700,
    );
    final blocks = <Widget>[];
    var start = 0;
    for (var i = 0; i < entry.segments.length; i++) {
      final segment = entry.segments[i];
      final end = segment.upTo.clamp(0, entry.content.length);
      if (end <= start) continue;
      final chunk = entry.content.substring(start, end);
      start = end;
      blocks.add(Text(chunk.trimRight(), style: baseStyle));
      // Empty uid marks text from before per-author parts existed, with
      // no real author to attribute - leave it unsigned.
      if (segment.uid.isEmpty) continue;
      final editable = segment.uid == editableUid && onEditPart != null;
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          // Same height with or without the button, so the gaps between
          // parts stay even.
          child: SizedBox(
            height: 28,
            child: Row(
              children: [
                Text('- ${nicknameFor(segment.uid)}', style: markerStyle),
                if (editable)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    tooltip: '고치기',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    color: Theme.of(context).disabledColor,
                    onPressed: () => onEditPart!(i),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    if (blocks.isEmpty) blocks.add(Text(entry.content, style: baseStyle));
    // Stretched, so the text spans the pane rather than shrink-wrapping
    // into a narrow column.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: blocks,
    );
  }
}
