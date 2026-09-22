import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../providers/providers.dart';

const List<int> kCategoryColors = [
  0xFFEF5350,
  0xFFFF7043,
  0xFFFFCA28,
  0xFF66BB6A,
  0xFF26C6DA,
  0xFF42A5F5,
  0xFF7E57C2,
  0xFFEC407A,
  0xFF8D6E63,
  0xFF78909C,
];

Future<void> showManageCategoriesSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const ManageCategoriesSheet(),
  );
}

class ManageCategoriesSheet extends ConsumerStatefulWidget {
  const ManageCategoriesSheet({super.key});

  @override
  ConsumerState<ManageCategoriesSheet> createState() =>
      _ManageCategoriesSheetState();
}

class _ManageCategoriesSheetState extends ConsumerState<ManageCategoriesSheet> {
  final _nameController = TextEditingController();
  int _selectedColor = kCategoryColors.first;
  bool _isPrivate = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final service = ref.read(firestoreServiceProvider);
    if (service == null) return;
    await service.addCategory(
      TodoCategory(
        id: const Uuid().v4(),
        name: name,
        colorValue: _selectedColor,
        order: DateTime.now().millisecondsSinceEpoch,
        isPrivate: _isPrivate,
      ),
    );
    _nameController.clear();
    setState(() => _isPrivate = false);
  }

  Future<void> _reorder(
    List<TodoCategory> categories,
    int oldIndex,
    int newIndex,
  ) async {
    final reordered = List<TodoCategory>.from(categories);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    final service = ref.read(firestoreServiceProvider);
    if (service == null) return;
    await service.reorderCategories(reordered.map((c) => c.id).toList());
  }

  Future<void> _deleteCategory(String id) async {
    final service = ref.read(firestoreServiceProvider);
    if (service == null) return;
    await service.deleteCategory(id);
  }

  Future<void> _togglePrivate(TodoCategory category) async {
    final service = ref.read(firestoreServiceProvider);
    if (service == null) return;
    await service.setCategoryPrivate(category.id, !category.isPrivate);
  }

  Future<void> _editCategory(TodoCategory category) async {
    final result = await showDialog<TodoCategory>(
      context: context,
      builder: (_) => _EditCategoryDialog(category: category),
    );
    if (result == null) return;
    final service = ref.read(firestoreServiceProvider);
    if (service == null) return;
    await service.updateCategory(result);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Padding(
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
          Text('카테고리 관리', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          categoriesAsync.when(
            data: (categories) => ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: (oldIndex, newIndex) =>
                  _reorder(categories, oldIndex, newIndex),
              children: [
                for (var i = 0; i < categories.length; i++)
                  ListTile(
                    key: ValueKey(categories[i].id),
                    onTap: () => _editCategory(categories[i]),
                    leading: CircleAvatar(
                      backgroundColor: Color(categories[i].colorValue),
                      radius: 10,
                    ),
                    title: Text(categories[i].name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            categories[i].isPrivate
                                ? Icons.lock_outline
                                : Icons.lock_open_outlined,
                            color: categories[i].isPrivate
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).disabledColor,
                          ),
                          tooltip: categories[i].isPrivate
                              ? '비공개 (친구에게 안 보임)'
                              : '공개 (친구에게 보임)',
                          onPressed: () => _togglePrivate(categories[i]),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteCategory(categories[i].id),
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(Icons.drag_handle),
                          ),
                        ),
                      ],
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
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '새 카테고리 이름',
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
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isPrivate,
            onChanged: (v) => setState(() => _isPrivate = v),
            title: const Text('비공개로 만들기'),
            subtitle: const Text('켜면 친구에게 이 카테고리와 할 일이 보이지 않아요'),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _addCategory, child: const Text('카테고리 추가')),
        ],
      ),
    );
  }
}

class _EditCategoryDialog extends StatefulWidget {
  final TodoCategory category;

  const _EditCategoryDialog({required this.category});

  @override
  State<_EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends State<_EditCategoryDialog> {
  late final TextEditingController _nameController;
  late int _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category.name);
    _selectedColor = widget.category.colorValue;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('카테고리 수정'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '카테고리 이름',
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
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(
              widget.category.copyWith(name: name, colorValue: _selectedColor),
            );
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}
