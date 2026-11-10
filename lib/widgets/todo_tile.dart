import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/todo_item.dart';
import 'clay.dart';

String todoCheckboxAsset(bool isDone) =>
    isDone ? 'assets/icons/cat_checked1.png' : 'assets/icons/cat_unchecked.png';

/// The cat checkbox's canvas; the drawing fills only its middle.
const kTodoCheckboxSize = 77.0;

/// Between the cat and the todo's title.
const kTodoCheckboxGap = 16.5;

/// The cat drawing, cropped to the cat: the png is mostly empty canvas,
/// with the cat a bit left of center (its box is ~52% x 34% of the image).
class CatCheckbox extends StatelessWidget {
  final bool isDone;

  const CatCheckbox({super.key, required this.isDone});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: kTodoCheckboxSize * 0.558,
    height: kTodoCheckboxSize * 0.4026,
    child: ClipRect(
      child: OverflowBox(
        maxWidth: kTodoCheckboxSize,
        maxHeight: kTodoCheckboxSize,
        child: Transform.translate(
          offset: const Offset(
            kTodoCheckboxSize * 0.0625,
            -kTodoCheckboxSize * 0.006,
          ),
          child: Image.asset(
            todoCheckboxAsset(isDone),
            width: kTodoCheckboxSize,
            height: kTodoCheckboxSize,
            // The png is 2048x2048: decoded whole it's a 16MB texture.
            cacheWidth: 256,
          ),
        ),
      ),
    ),
  );
}

/// A todo's title, in the list and while it's dragged.
const kTodoTitleSize = 15.0;

class TodoTile extends StatelessWidget {
  final TodoItem todo;
  final TodoCategory? category;
  final ValueChanged<bool?>? onToggle;
  final VoidCallback? onTap;

  /// Swipe to delete; resolves to whether the todo actually went away.
  final Future<bool> Function()? onDelete;
  final Widget? dragHandle;

  /// Space above the row's card.
  final double topPadding;

  const TodoTile({
    super.key,
    required this.todo,
    required this.category,
    this.onToggle,
    this.onTap,
    this.onDelete,
    this.dragHandle,
    this.topPadding = 10,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 0),
      child: Clay(
        small: true,
        radius: 22,
        // A shadow in the category's color sets each card off the white
        // list card it sits on, and says whose it is at a glance.
        shadowColor: category != null ? Color(category!.colorValue) : null,
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onToggle == null
                        ? null
                        : () => onToggle!(!todo.isDone),
                    // Pads the cropped cat back out to a comfortable target.
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 10,
                      ),
                      child: CatCheckbox(isDone: todo.isDone),
                    ),
                  ),
                  const SizedBox(width: kTodoCheckboxGap - 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: todo.title),
                              for (final (show, icon, label) in [
                                (todo.isRepeating, Icons.repeat, '반복'),
                                (
                                  todo.remindMinutes != null,
                                  Icons.notifications_none,
                                  '알림',
                                ),
                                (todo.isPrivate, Icons.lock_outline, '나만 보기'),
                              ])
                                if (show)
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Icon(
                                        icon,
                                        size: 14,
                                        semanticLabel: label,
                                        color: Theme.of(context).disabledColor,
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                          style: TextStyle(
                            fontFamily: 'GriunFromsol',
                            fontSize: kTodoTitleSize,
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
                          // The whole memo, every line of it; the icon stays
                          // by the first line.
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.notes,
                                  size: 13,
                                  color: Theme.of(context).disabledColor,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  todo.note!,
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
        ),
      ),
    );

    if (onDelete == null) return content;

    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: EdgeInsets.fromLTRB(16, topPadding, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (_) => onDelete!(),
      child: content,
    );
  }
}
