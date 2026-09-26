import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../models/chat_message.dart';
import '../providers/providers.dart';

class FriendChatScreen extends ConsumerStatefulWidget {
  final String uid;

  const FriendChatScreen({super.key, required this.uid});

  @override
  ConsumerState<FriendChatScreen> createState() => _FriendChatScreenState();
}

class _FriendChatScreenState extends ConsumerState<FriendChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _composerFocus = FocusNode();
  bool _sending = false;
  ChatMessage? _replyTo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(firestoreServiceProvider)?.markChatRead(widget.uid);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  // The list is reversed, so offset 0 is the newest message.
  void _scrollToLatest() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
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
    try {
      await ref
          .read(firestoreServiceProvider)
          ?.sendChatMessage(widget.uid, text, replyToId: replyToId);
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
          ?.sendChatMessage(widget.uid, '', imageBase64: base64);
      _scrollToLatest();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(friendProfileProvider(widget.uid));
    final nickname = (profileAsync.value?['nickname'] as String?)?.trim();
    final displayText = (nickname != null && nickname.isNotEmpty)
        ? nickname
        : widget.uid.substring(0, 8);
    final myUid = ref.watch(authStateProvider).value?.uid ?? '';
    final messagesAsync = ref.watch(chatMessagesProvider(widget.uid));
    final friendLastRead = ref.watch(chatFriendLastReadProvider(widget.uid)).value;

    return Scaffold(
      appBar: AppBar(title: Text(displayText)),
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
                // Reversed so the list stays anchored at the newest message:
                // rebuilds and the composer growing (reply bar) can't move it.
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, reversedIndex) {
                    final index = messages.length - 1 - reversedIndex;
                    final message = messages[index];
                    final isMe = message.senderUid == myUid;
                    final showRead =
                        isMe &&
                        index == lastMineIndex &&
                        friendLastRead != null &&
                        !friendLastRead.isBefore(message.createdAt);
                    return _MessageBubble(
                      message: message,
                      isMe: isMe,
                      otherUid: widget.uid,
                      showRead: showRead,
                      repliedMessage: message.replyToId == null
                          ? null
                          : byId[message.replyToId],
                      onReply: (m) => setState(() {
                        _replyTo = m;
                        _composerFocus.requestFocus();
                      }),
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
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                          textInputAction: TextInputAction.send,
                          decoration: const InputDecoration(
                            hintText: '메시지 보내기',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
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

class _MessageBubble extends ConsumerWidget {
  final ChatMessage message;
  final bool isMe;
  final String otherUid;
  final bool showRead;
  final ChatMessage? repliedMessage;
  final ValueChanged<ChatMessage>? onReply;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.otherUid,
    this.showRead = false,
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
            ?.updateChatMessage(otherUid, message.id, newText);
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
            ?.deleteChatMessage(otherUid, message.id);
      }
    }
  }

  void _openFullImage(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: Image.memory(base64Decode(message.imageBase64!)),
        ),
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
                        base64Decode(message.imageBase64!),
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
          if (showRead)
            Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 4),
              child: Text(
                '읽음',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).disabledColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
