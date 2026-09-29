import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../models/chat_message.dart';
import '../models/group_chat.dart';
import '../providers/providers.dart';
import '../utils/chat_enter.dart';
import '../utils/display_name.dart';

// Decode each photo once - see friend_chat_screen.dart's _photoBytes for why.
final _photoBytes = <String, Uint8List>{};
Uint8List _photoOf(ChatMessage message) => _photoBytes.putIfAbsent(
  message.id,
  () => base64Decode(message.imageBase64!),
);

String _memberDisplayName(WidgetRef ref, String uid) {
  return displayNameFor(ref.watch(friendProfileProvider(uid)).value, uid);
}

class GroupChatScreen extends ConsumerStatefulWidget {
  final GroupChat group;

  const GroupChatScreen({super.key, required this.group});

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _composerFocus = FocusNode();
  String _composerTextBefore = '';
  final _bubbleKeys = <String, GlobalKey>{};
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _sending = false;
  ChatMessage? _replyTo;

  String get _groupId => widget.group.id;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_focusComposerOnEnter);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(firestoreServiceProvider)?.markGroupRead(_groupId);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    HardwareKeyboard.instance.removeHandler(_focusComposerOnEnter);
    _composerFocus.dispose();
    super.dispose();
  }

  void _onComposerChanged(String text) {
    final before = _composerTextBefore;
    _composerTextBefore = text;
    if (!chatEnterSendsOnDesktop) return;
    final toSend = bareEnterSubmission(
      before,
      text,
      _controller.selection.baseOffset,
      shiftPressed: HardwareKeyboard.instance.isShiftPressed,
    );
    if (toSend == null) return;
    _controller.text = toSend;
    _send();
  }

  /// Enter anywhere on this screen jumps into the message box, so typing
  /// the next message never needs a click first.
  bool _focusComposerOnEnter(KeyEvent event) {
    if (event is! KeyDownEvent ||
        (event.logicalKey != LogicalKeyboardKey.enter &&
            event.logicalKey != LogicalKeyboardKey.numpadEnter) ||
        _composerFocus.hasFocus ||
        !mounted ||
        !(ModalRoute.of(context)?.isCurrent ?? false)) {
      return false;
    }
    _composerFocus.requestFocus();
    return true;
  }

  void _scrollToLatest() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _startReply(ChatMessage message) {
    final oldViewport = _scrollController.hasClients
        ? _scrollController.position.viewportDimension
        : null;
    setState(() => _replyTo = message);
    _composerFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (oldViewport != null && _scrollController.hasClients) {
        final position = _scrollController.position;
        final shrink = oldViewport - position.viewportDimension;
        if (shrink > 0) {
          position.jumpTo(
            (position.pixels + shrink)
                .clamp(position.minScrollExtent, position.maxScrollExtent)
                .toDouble(),
          );
        }
      }
      final bubble = _bubbleKeys[message.id]?.currentContext;
      if (bubble == null) return;
      for (final policy in [
        ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      ]) {
        Scrollable.ensureVisible(bubble, alignmentPolicy: policy);
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final replyToId = _replyTo?.id;
    setState(() {
      _sending = true;
      _replyTo = null;
    });
    _controller.clear();
    _composerTextBefore = '';
    _composerFocus.requestFocus();
    try {
      await ref
          .read(firestoreServiceProvider)
          ?.sendGroupMessage(_groupId, text, replyToId: replyToId);
      _scrollToLatest();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendImage() async {
    if (_sending) return;
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    setState(() => _sending = true);
    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;
      final resized = img.copyResize(
        decoded,
        width: decoded.width >= decoded.height ? 1080 : null,
        height: decoded.height > decoded.width ? 1080 : null,
      );
      final jpeg = img.encodeJpg(resized, quality: 78);
      final base64 = base64Encode(Uint8List.fromList(jpeg));
      await ref
          .read(firestoreServiceProvider)
          ?.sendGroupMessage(_groupId, '', imageBase64: base64);
      _scrollToLatest();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('단톡방을 나갈까요?'),
        content: const Text('나가면 대화 목록에서 사라지고, 다시 초대받아야 들어올 수 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(firestoreServiceProvider)?.leaveGroupChat(_groupId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.watch(authStateProvider).value?.uid ?? '';
    final otherMembers = widget.group.members.where((m) => m != myUid).toList();
    final name = widget.group.name?.trim();
    final title = (name != null && name.isNotEmpty)
        ? name
        : otherMembers.map((m) => _memberDisplayName(ref, m)).join(', ');

    final messagesAsync = ref.watch(groupMessagesProvider(_groupId));
    final lastReadMap =
        ref.watch(groupLastReadProvider(_groupId)).value ?? const {};
    ref.listen(groupMessagesProvider(_groupId), (_, next) {
      final newest = next.value?.lastOrNull;
      if (newest != null && newest.senderUid != myUid) {
        ref.read(firestoreServiceProvider)?.markGroupRead(_groupId);
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: '참여자',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: _MembersDrawer(
        members: widget.group.members,
        myUid: myUid,
        onLeave: _leaveGroup,
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      '아직 나눈 대화가 없어요.',
                      style: TextStyle(color: Theme.of(context).disabledColor),
                    ),
                  );
                }
                final lastMineIndex = messages.lastIndexWhere(
                  (m) => m.senderUid == myUid,
                );
                final byId = {for (final m in messages) m.id: m};
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, reversedIndex) {
                    final index = messages.length - 1 - reversedIndex;
                    final message = messages[index];
                    final isMe = message.senderUid == myUid;
                    String? readLabel;
                    if (isMe && index == lastMineIndex) {
                      final unread = otherMembers.where((m) {
                        final t = lastReadMap[m];
                        return t == null || t.isBefore(message.createdAt);
                      }).length;
                      readLabel = unread == 0 ? '읽음' : '안읽음 $unread';
                    }
                    // KakaoTalk-style: a run of messages from one person
                    // only names them on the first bubble.
                    final continuesRun =
                        index > 0 &&
                        messages[index - 1].senderUid == message.senderUid;
                    return _GroupMessageBubble(
                      key: _bubbleKeys.putIfAbsent(message.id, GlobalKey.new),
                      message: message,
                      isMe: isMe,
                      groupId: _groupId,
                      senderName: isMe || continuesRun
                          ? null
                          : _memberDisplayName(ref, message.senderUid),
                      readLabel: readLabel,
                      repliedMessage: message.replyToId == null
                          ? null
                          : byId[message.replyToId],
                      onReply: _startReply,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_replyTo != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border(
                          left: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _replyTo!.imageBase64 != null
                                  ? '사진'
                                  : _replyTo!.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _replyTo = null),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _sending ? null : _sendImage,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _composerFocus,
                          minLines: 1,
                          maxLines: 5,
                          keyboardType: TextInputType.multiline,
                          textInputAction: chatEnterSendsOnDesktop
                              ? TextInputAction.newline
                              : TextInputAction.send,
                          onChanged: _onComposerChanged,
                          decoration: const InputDecoration(
                            hintText: '메시지 보내기',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          // Don't drop focus on Enter: the next message
                          // goes straight into the same box.
                          onEditingComplete: () {},
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sending ? null : _send,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MembersDrawer extends StatelessWidget {
  final List<String> members;
  final String myUid;
  final VoidCallback onLeave;

  const _MembersDrawer({
    required this.members,
    required this.myUid,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '참여자 ${members.length}명',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  for (final uid in members)
                    _MemberProfileTile(uid: uid, isMe: uid == myUid),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('나가기'),
              onTap: () {
                Navigator.of(context).pop();
                onLeave();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberProfileTile extends ConsumerWidget {
  final String uid;
  final bool isMe;

  const _MemberProfileTile({required this.uid, required this.isMe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(friendProfileProvider(uid)).value;
    final displayText = displayNameFor(profile, uid);
    final bio = (profile?['bio'] as String?)?.trim();
    final photoBase64 = profile?['photoBase64'] as String?;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: CircleAvatar(
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
      title: Text(isMe ? '$displayText (나)' : displayText),
      subtitle: (bio != null && bio.isNotEmpty)
          ? Text(bio, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
    );
  }
}

class _GroupMessageBubble extends ConsumerWidget {
  final ChatMessage message;
  final bool isMe;
  final String groupId;
  final String? senderName;
  final String? readLabel;
  final ChatMessage? repliedMessage;
  final ValueChanged<ChatMessage>? onReply;

  const _GroupMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.groupId,
    this.senderName,
    this.readLabel,
    this.repliedMessage,
    this.onReply,
  });

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final hasImage = message.imageBase64 != null;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: const Text('답장'),
              onTap: () => Navigator.of(context).pop('reply'),
            ),
            if (isMe && !hasImage)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('수정'),
                onTap: () => Navigator.of(context).pop('edit'),
              ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('삭제'),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;

    if (action == 'reply') {
      onReply?.call(message);
    } else if (action == 'edit') {
      final editController = TextEditingController(text: message.text);
      final newText = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('메시지 수정'),
          content: TextField(controller: editController, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(editController.text.trim()),
              child: const Text('저장'),
            ),
          ],
        ),
      );
      if (newText != null && newText.isNotEmpty && newText != message.text) {
        await ref
            .read(firestoreServiceProvider)
            ?.updateGroupMessage(groupId, message.id, newText);
      }
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('메시지를 삭제할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('삭제'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await ref
            .read(firestoreServiceProvider)
            ?.deleteGroupMessage(groupId, message.id);
      }
    }
  }

  void _openFullImage(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(child: Image.memory(_photoOf(message))),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = message.imageBase64 != null;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (senderName != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                senderName!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).disabledColor,
                ),
              ),
            ),
          GestureDetector(
            onLongPress: () => _showActions(context, ref),
            onSecondaryTap: () => _showActions(context, ref),
            onTap: hasImage ? () => _openFullImage(context) : null,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: hasImage
                  ? const EdgeInsets.all(4)
                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (repliedMessage != null)
                    Container(
                      margin: EdgeInsets.only(bottom: hasImage ? 4 : 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isMe
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurfaceVariant)
                                .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        repliedMessage!.imageBase64 != null
                            ? '사진'
                            : repliedMessage!.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isMe
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (hasImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _photoOf(message),
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else ...[
                    Text(
                      message.text,
                      style: TextStyle(
                        color: isMe
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (message.edited) ...[
                      const SizedBox(height: 2),
                      Text(
                        '수정됨',
                        style: TextStyle(
                          fontSize: 10,
                          color:
                              (isMe
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurfaceVariant)
                                  .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          if (readLabel != null)
            Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 4),
              child: Text(
                readLabel!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: readLabel!.startsWith('안읽음')
                      ? FontWeight.w700
                      : null,
                  color: readLabel!.startsWith('안읽음')
                      ? colorScheme.primary
                      : Theme.of(context).disabledColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
