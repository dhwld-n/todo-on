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

class _SharedDiaryBody extends ConsumerStatefulWidget {
  final DateTime date;
  final String friendUid;

  const _SharedDiaryBody({required this.date, required this.friendUid});

  @override
  ConsumerState<_SharedDiaryBody> createState() => _SharedDiaryBodyState();
}

/// Splits a shared diary entry into the locked (already-turned-in) prefix
/// and the segments behind it. Only a writer's own still-open trailing
/// segment is editable; anything before that - the other person's text, or
/// the writer's own earlier turns - is locked.
(String, List<DiarySegment>) splitDiaryEditable(
  SharedDiaryEntry? entry,
  String? myUid,
) {
  final content = entry?.content ?? '';
  final segments = entry?.segments ?? const <DiarySegment>[];
  if (segments.isEmpty) return ('', segments);
  if (segments.last.uid == myUid) {
    final start = segments.length >= 2
        ? segments[segments.length - 2].upTo.clamp(0, content.length)
        : 0;
    return (
      content.substring(0, start),
      segments.sublist(0, segments.length - 1),
    );
  }
  return (content, segments);
}

/// Scaffold strips the keyboard inset out of the MediaQuery its body sees,
/// so read it straight off the view.
bool _keyboardOpen(BuildContext context) =>
    View.of(context).viewInsets.bottom > 0;

/// The read-only text above the editor gets less room while the soft
/// keyboard is up, so the input itself stays visible on a phone.
double _lockedBoxMaxHeight(BuildContext context) =>
    _keyboardOpen(context) ? 64 : 120;

/// What to save for a shared diary edit, or null if nothing actually
/// changed. Tapping in and blurring back out without typing anything must
/// not create a zero-length "turn" for whoever merely looked - that would
/// silently lock the other person's already-written text out from under
/// them.
(String, List<DiarySegment>)? computeDiarySave({
  required SharedDiaryEntry? oldEntry,
  required String lockedPrefix,
  required String typedTail,
  required String myUid,
}) {
  final newContent = lockedPrefix + typedTail;
  if (newContent == (oldEntry?.content ?? '')) return null;
  final oldSegments = oldEntry?.segments ?? const <DiarySegment>[];
  return (
    newContent,
    DiarySegment.update(oldSegments, myUid, newContent.length),
  );
}

class _SharedDiaryBodyState extends ConsumerState<_SharedDiaryBody> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  String? _loadedKey;
  String? _dateKey;
  bool _editing = false;
  String? _syncedContent;
  // The part of the entry that isn't my own trailing writing - shown
  // read-only so a friend's text (or my own older turns) can't be edited.
  String _lockedPrefix = '';
  List<DiarySegment> _lockedSegments = const [];

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
    if (_focusNode.hasFocus) {
      _editing = true;
    } else if (_editing) {
      _debounce?.cancel();
      _save();
      setState(() => _editing = false);
    }
  }

  void _save() {
    final dateKey = _dateKey;
    final myUid = ref.read(authStateProvider).value?.uid;
    if (dateKey == null || myUid == null) return;
    final oldEntry = ref
        .read(
          sharedDiaryEntryProvider((
            otherUid: widget.friendUid,
            dateKey: dateKey,
          )),
        )
        .value;
    final result = computeDiarySave(
      oldEntry: oldEntry,
      lockedPrefix: _lockedPrefix,
      typedTail: _controller.text,
      myUid: myUid,
    );
    if (result == null) return;
    final (newContent, newSegments) = result;
    ref
        .read(firestoreServiceProvider)
        ?.saveSharedDiaryEntry(
          widget.friendUid,
          dateKey,
          newContent,
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
    final myNickname = displayNameFor(
      ref.watch(profileDocProvider).value,
      myUid ?? '',
    );
    final friendNickname = displayNameFor(
      ref.watch(friendProfileProvider(widget.friendUid)).value,
      widget.friendUid,
    );

    return entryAsync.when(
      data: (entry) {
        // Re-split on a date switch, and on anyone's new write while I'm
        // not mid-typing, so the text above the box stays live.
        if (_loadedKey != entryKey ||
            (!_editing && entry?.content != _syncedContent)) {
          _loadedKey = entryKey;
          _syncedContent = entry?.content;
          final (lockedPrefix, lockedSegments) = splitDiaryEditable(
            entry,
            myUid,
          );
          _lockedPrefix = lockedPrefix;
          _lockedSegments = lockedSegments;
          _controller.text =
              entry?.content.substring(lockedPrefix.length) ?? '';
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
        if (entry != null && myUid != null && entry.hasUnseenEditFor(myUid)) {
          // Open on screen = seen; clears the dot on this friend's chip.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(firestoreServiceProvider)
                ?.markSharedDiarySeen(
                  widget.friendUid,
                  dateKey,
                  entry.updatedAt,
                );
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_lockedPrefix.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: _lockedBoxMaxHeight(context),
                      ),
                      child: SingleChildScrollView(
                        child: SizedBox(
                          width: double.infinity,
                          child: _AttributedDiaryText(
                            entry: SharedDiaryEntry(
                              dateKey: dateKey,
                              content: _lockedPrefix,
                              updatedAt: entry?.updatedAt ?? DateTime.now(),
                              updatedBy: entry?.updatedBy ?? '',
                              segments: _lockedSegments,
                            ),
                            nicknameFor: (uid) =>
                                uid == myUid ? myNickname : friendNickname,
                          ),
                        ),
                      ),
                    ),
                  if (_lockedPrefix.isNotEmpty) const SizedBox(height: 8),
                  Expanded(
                    child: TextField(
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
                    ),
                  ),
                ],
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

/// Same collaborative-editing shape as [_SharedDiaryBody] but for a
/// multi-member [DiaryGroup] instead of a single friend - the lock/save
/// logic (splitDiaryEditable / computeDiarySave) doesn't care how many
/// people are writing, only who wrote last.
class _DiaryGroupBody extends ConsumerStatefulWidget {
  final DateTime date;
  final DiaryGroup group;

  const _DiaryGroupBody({required this.date, required this.group});

  @override
  ConsumerState<_DiaryGroupBody> createState() => _DiaryGroupBodyState();
}

class _DiaryGroupBodyState extends ConsumerState<_DiaryGroupBody> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  String? _loadedKey;
  String? _dateKey;
  bool _editing = false;
  String? _syncedContent;
  String _lockedPrefix = '';
  List<DiarySegment> _lockedSegments = const [];

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
    if (_focusNode.hasFocus) {
      _editing = true;
    } else if (_editing) {
      _debounce?.cancel();
      _save();
      setState(() => _editing = false);
    }
  }

  void _save() {
    final dateKey = _dateKey;
    final myUid = ref.read(authStateProvider).value?.uid;
    if (dateKey == null || myUid == null) return;
    final oldEntry = ref
        .read(
          diaryGroupEntryProvider((groupId: widget.group.id, dateKey: dateKey)),
        )
        .value;
    final result = computeDiarySave(
      oldEntry: oldEntry,
      lockedPrefix: _lockedPrefix,
      typedTail: _controller.text,
      myUid: myUid,
    );
    if (result == null) return;
    final (newContent, newSegments) = result;
    ref
        .read(firestoreServiceProvider)
        ?.saveDiaryGroupEntry(
          widget.group.id,
          dateKey,
          newContent,
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
    final entryKey = '${widget.group.id}_$dateKey';
    final entryAsync = ref.watch(
      diaryGroupEntryProvider((groupId: widget.group.id, dateKey: dateKey)),
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
        // Re-split on a date switch, and on anyone's new write while I'm
        // not mid-typing, so the text above the box stays live.
        if (_loadedKey != entryKey ||
            (!_editing && entry?.content != _syncedContent)) {
          _loadedKey = entryKey;
          _syncedContent = entry?.content;
          final (lockedPrefix, lockedSegments) = splitDiaryEditable(
            entry,
            myUid,
          );
          _lockedPrefix = lockedPrefix;
          _lockedSegments = lockedSegments;
          _controller.text =
              entry?.content.substring(lockedPrefix.length) ?? '';
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
        }
        if (entry != null && myUid != null && entry.hasUnseenEditFor(myUid)) {
          // Open on screen = seen; clears the dot on this group's chip.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(firestoreServiceProvider)
                ?.markDiaryGroupSeen(widget.group.id, dateKey, entry.updatedAt);
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_lockedPrefix.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: _lockedBoxMaxHeight(context),
                      ),
                      child: SingleChildScrollView(
                        child: SizedBox(
                          width: double.infinity,
                          child: _AttributedDiaryText(
                            entry: SharedDiaryEntry(
                              dateKey: dateKey,
                              content: _lockedPrefix,
                              updatedAt: entry?.updatedAt ?? DateTime.now(),
                              updatedBy: entry?.updatedBy ?? '',
                              segments: _lockedSegments,
                            ),
                            nicknameFor: nicknameFor,
                          ),
                        ),
                      ),
                    ),
                  if (_lockedPrefix.isNotEmpty) const SizedBox(height: 8),
                  Expanded(
                    child: TextField(
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
                    ),
                  ),
                ],
              ),
            ),
            if (entry != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '마지막 수정: ${entry.updatedBy == myUid ? '나' : nicknameFor(entry.updatedBy)} · '
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

/// Read-only rendering of the shared diary text with a "- 닉네임" marker
/// right after each contributor's block, tap-to-edit switches to the
/// plain TextField in the parent.
class _AttributedDiaryText extends StatelessWidget {
  final SharedDiaryEntry entry;
  final String Function(String uid) nicknameFor;

  const _AttributedDiaryText({required this.entry, required this.nicknameFor});

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
        final nickname = nicknameFor(segment.uid);
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
