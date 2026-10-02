import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/todo_item.dart';
import '../providers/providers.dart';

Future<void> showAddEditTodoSheet(
  BuildContext context,
  WidgetRef ref, {
  TodoItem? existing,
  DateTime? initialDate,
  String? initialCategoryId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => AddEditTodoSheet(
      existing: existing,
      initialDate: initialDate,
      initialCategoryId: initialCategoryId,
    ),
  );
}

class AddEditTodoSheet extends ConsumerStatefulWidget {
  final TodoItem? existing;
  final DateTime? initialDate;
  final String? initialCategoryId;
  const AddEditTodoSheet({
    super.key,
    this.existing,
    this.initialDate,
    this.initialCategoryId,
  });

  @override
  ConsumerState<AddEditTodoSheet> createState() => _AddEditTodoSheetState();
}

class _AddEditTodoSheetState extends ConsumerState<AddEditTodoSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  String? _categoryId;
  late DateTime _dueDate;
  late bool _showNoteField;
  late bool _isPrivate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    _noteController = TextEditingController(text: widget.existing?.note ?? '');
    _categoryId = widget.existing?.categoryId ?? widget.initialCategoryId;
    _dueDate = widget.existing?.dueDate ?? widget.initialDate ?? DateTime.now();
    // Adding a new todo starts with just the title field; note can be
    // expanded on demand. Editing shows the note if one already exists.
    _showNoteField = widget.existing != null && widget.existing!.note != null;
    _isPrivate = widget.existing?.isPrivate ?? false;
  }

  bool _categoryIsPrivate(List<TodoCategory> categories) =>
      _categoryId != null &&
      categories.any((c) => c.id == _categoryId && c.isPrivate);

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  bool _saving = false;

  /// One press, one item: the write takes a moment to reach the server,
  /// and presses in the meantime must not add copies.
  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _saveOnce();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveOnce() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final note = _noteController.text.trim();
    final service = ref.read(firestoreServiceProvider);
    if (service == null) return;

    final isPrivate = _categoryIsPrivate(
      ref.read(categoriesProvider).value ?? const <TodoCategory>[],
    );

    if (widget.existing == null) {
      final todo = TodoItem(
        id: const Uuid().v4(),
        title: title,
        categoryId: _categoryId,
        isDone: false,
        dueDate: _dueDate,
        createdAt: DateTime.now(),
        order: DateTime.now().millisecondsSinceEpoch,
        note: note.isEmpty ? null : note,
        categoryIsPrivate: isPrivate,
        isPrivate: _isPrivate,
      );
      await service.addTodo(todo);
    } else {
      final updated = widget.existing!.copyWith(
        title: title,
        categoryId: _categoryId,
        clearCategory: _categoryId == null,
        dueDate: _dueDate,
        note: note.isEmpty ? null : note,
        clearNote: note.isEmpty,
        categoryIsPrivate: isPrivate,
        isPrivate: _isPrivate,
      );
      await service.updateTodo(updated);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.existing == null ? '할 일 추가' : '할 일 수정',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (widget.existing != null)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    tooltip: '삭제',
                    onPressed: () async {
                      await ref
                          .read(firestoreServiceProvider)
                          ?.deleteTodo(widget.existing!.id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '할 일',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            if (_showNoteField) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                autofocus: widget.existing == null,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '메모',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showNoteField = true),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('메모 추가'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
            if (widget.existing != null) ...[
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final tomorrow = today.add(const Duration(days: 1));
                  final dueDay = DateTime(
                    _dueDate.year,
                    _dueDate.month,
                    _dueDate.day,
                  );
                  return Row(
                    children: [
                      ChoiceChip(
                        label: const Text('오늘 하기'),
                        selected: dueDay == today,
                        onSelected: (_) => setState(() => _dueDate = today),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('내일 하기'),
                        selected: dueDay == tomorrow,
                        onSelected: (_) => setState(() => _dueDate = tomorrow),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDueDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(DateFormat('yyyy년 M월 d일').format(_dueDate)),
              ),
            ],
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final inPrivateCategory = _categoryIsPrivate(
                  ref.watch(categoriesProvider).value ?? const [],
                );
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isPrivate || inPrivateCategory,
                  onChanged: inPrivateCategory
                      ? null
                      : (v) => setState(() => _isPrivate = v),
                  secondary: const Icon(Icons.lock_outline),
                  title: const Text('나만 보기'),
                  subtitle: Text(
                    inPrivateCategory
                        ? '비공개 카테고리라 이미 친구에게 안 보여요'
                        : '켜면 친구에게 이 할 일이 보이지 않아요',
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(widget.existing == null ? '추가' : '저장'),
            ),
          ],
        ),
      ),
    );
  }
}
