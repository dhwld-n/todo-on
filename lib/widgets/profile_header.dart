import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../providers/providers.dart';
import 'manage_categories_sheet.dart' show kCategoryColors;

Color _colorFor(String seed) {
  final hash = seed.codeUnits.fold<int>(0, (acc, c) => acc + c);
  return Color(kCategoryColors[hash % kCategoryColors.length]);
}

class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    final profileAsync = ref.watch(profileDocProvider);
    final user = userAsync.value;
    final profile = profileAsync.value;
    final nickname = user?.displayName?.trim();
    final displayText = (nickname != null && nickname.isNotEmpty)
        ? nickname
        : (user?.email?.split('@').first ?? '사용자');
    final bio = (profile?['bio'] as String?)?.trim();
    final photoBase64 = profile?['photoBase64'] as String?;
    final initial = displayText.isNotEmpty ? displayText[0] : '?';
    final avatarColor = _colorFor(user?.uid ?? displayText);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showDialog(
          context: context,
          builder: (_) => _EditProfileDialog(
            initialNickname: displayText,
            initialBio: bio ?? '',
            initialPhotoBase64: photoBase64,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: avatarColor,
                backgroundImage: photoBase64 != null
                    ? MemoryImage(base64Decode(photoBase64))
                    : null,
                child: photoBase64 == null
                    ? Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayText,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'GriunFromsol',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (bio != null && bio.isNotEmpty)
                      Text(
                        bio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).disabledColor,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.edit_outlined,
                size: 16,
                color: Theme.of(context).disabledColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditProfileDialog extends ConsumerStatefulWidget {
  final String initialNickname;
  final String initialBio;
  final String? initialPhotoBase64;

  const _EditProfileDialog({
    required this.initialNickname,
    required this.initialBio,
    required this.initialPhotoBase64,
  });

  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _bioController;
  String? _photoBase64;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.initialNickname);
    _bioController = TextEditingController(text: widget.initialBio);
    _photoBase64 = widget.initialPhotoBase64;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;
    final resized = img.copyResize(
      decoded,
      width: decoded.width >= decoded.height ? 256 : null,
      height: decoded.height > decoded.width ? 256 : null,
    );
    final jpeg = img.encodeJpg(resized, quality: 82);
    setState(() => _photoBase64 = base64Encode(Uint8List.fromList(jpeg)));
  }

  Future<void> _save() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) return;
    setState(() => _saving = true);
    await ref.read(authServiceProvider).updateDisplayName(nickname);
    await ref
        .read(firestoreServiceProvider)
        ?.saveProfile(
          nickname: nickname,
          bio: _bioController.text.trim(),
          photoBase64: _photoBase64,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final avatarColor = _colorFor(_nicknameController.text);
    return AlertDialog(
      title: const Text('프로필 수정'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: avatarColor,
                      backgroundImage: _photoBase64 != null
                          ? MemoryImage(base64Decode(_photoBase64!))
                          : null,
                      child: _photoBase64 == null
                          ? Text(
                              _nicknameController.text.isNotEmpty
                                  ? _nicknameController.text[0]
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(labelText: '닉네임'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '자기소개',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('저장'),
        ),
      ],
    );
  }
}
