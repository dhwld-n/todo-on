import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/habit.dart';
import '../providers/providers.dart';
import 'manage_categories_sheet.dart' show kCategoryColors;

Future<void> showManageHabitsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const ManageHabitsSheet(),
  );
}

class ManageHabitsSheet extends ConsumerStatefulWidget {
  const ManageHabitsSheet({super.key});

  @override
  ConsumerState<ManageHabitsSheet> createState() => _ManageHabitsSheetState();
}

class _ManageHabitsSheetState extends ConsumerState<ManageHabitsSheet> {
  final _emojiController = TextEditingController(text: '⭐');
  final _nameController = TextEditingController();
  final _subtitleController = TextEditingController();
  int _selectedColor = kCategoryColors.first;

  @override
  void dispose() {
    _emojiController.dispose();
    _nameController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  Future<void> _addHabit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final service = ref.read(firestoreServiceProvider);
    if (service == null) return;
    final emoji = _emojiController.text.trim();
    final subtitle = _subtitleController.text.trim();
    await service.addHabit(
      Habit(
        id: const Uuid().v4(),
        name: name,
        subtitle: subtitle.isEmpty ? null : subtitle,
        emoji: emoji.isEmpty ? '⭐' : emoji,
        colorValue: _selectedColor,
        order: DateTime.now().millisecondsSinceEpoch,
        createdAt: DateTime.now(),
      ),
    );
    _nameController.clear();
    _subtitleController.clear();
    setState(() => _emojiController.text = '⭐');
  }

  Future<void> _deleteHabit(String id) async {
    final service = ref.read(firestoreServiceProvider);
    if (service == null) return;
    await service.deleteHabit(id);
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('습관 관리', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            habitsAsync.when(
              data: (habits) => Column(
                children: [
                  for (final h in habits)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(
                          h.colorValue,
                        ).withValues(alpha: 0.16),
                        radius: 16,
                        child: Text(
                          h.emoji,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      title: Text(h.name),
                      subtitle: h.subtitle == null ? null : Text(h.subtitle!),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteHabit(h.id),
                      ),
                    ),
                  if (habits.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '아직 습관이 없어요.',
                        style: TextStyle(
                          color: Theme.of(context).disabledColor,
                        ),
                      ),
                    ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => Text('오류: $e'),
            ),
            const Divider(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 64,
                  child: TextField(
                    controller: _emojiController,
                    textAlign: TextAlign.center,
                    maxLength: 2,
                    decoration: const InputDecoration(
                      labelText: '이모지',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '습관 이름',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subtitleController,
              decoration: const InputDecoration(
                labelText: '설명 (선택)',
                hintText: '예: 근력 운동 30분',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in kCategoryColors)
                  GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: CircleAvatar(
                      backgroundColor: Color(color),
                      radius: 16,
                      child: _selectedColor == color
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _addHabit, child: const Text('습관 추가')),
          ],
        ),
      ),
    );
  }
}
