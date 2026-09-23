import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/todo_item.dart';

class TodoTile extends StatelessWidget {
  final TodoItem todo;
  final TodoCategory? category;
  final ValueChanged<bool?>? onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Widget? dragHandle;

  const TodoTile({
    super.key,
    required this.todo,
    required this.category,
    this.onToggle,
    this.onTap,
    this.onDelete,
    this.dragHandle,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onToggle == null
                      ? null
                      : () => onToggle!(!todo.isDone),
                  child: Image.asset(
                    todo.isDone
                        ? 'assets/icons/cat_checked.png'
                        : 'assets/icons/cat_unchecked.png',
                    width: 96,
                    height: 96,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        todo.title,
                        style: TextStyle(
                          fontFamily: 'GriunFromsol',
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: todo.isDone
                              ? Theme.of(context).disabledColor
                              : null,
                        ),
                      ),
                      if (category != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Color(category!.colorValue),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              category!.name,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                      if (todo.note != null && todo.note!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.notes,
                              size: 13,
                              color: Theme.of(context).disabledColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                todo.note!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context).disabledColor,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                ?dragHandle,
              ],
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          indent: 56,
          endIndent: 56,
          color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
        ),
      ],
    );

    if (onDelete == null) return content;

    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) => onDelete!(),
      child: content,
    );
  }
}
