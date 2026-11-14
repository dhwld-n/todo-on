import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';

import '../models/todo_item.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import 'paper.dart';

/// The todos picked out to move together: by dragging a box over them with
/// the mouse, or by long-pressing (then tapping) rows.
final selectedTodoIdsProvider = StateProvider<Set<String>>((ref) => const {});

/// Moves [todos] onto [day] and clears the selection. A repeating todo
/// follows its own days, so it stays put; the snack bar says how many did.
Future<void> moveTodosToDay(
  BuildContext context,
  WidgetRef ref,
  Iterable<TodoItem> todos,
  DateTime day,
) async {
  // The calendar hands over UTC midnights; the day is what matters.
  day = DateTime(day.year, day.month, day.day);
  final movable = [
    for (final t in todos)
      if (!t.isRepeating) t.id,
  ];
  final kept = todos.length - movable.length;
  ref.read(selectedTodoIdsProvider.notifier).state = const {};
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (movable.isNotEmpty) {
    await ref.read(firestoreServiceProvider)?.moveTodosToDay(movable, day);
  }
  messenger?.showSnackBar(
    SnackBar(
      content: Text(
        [
          if (movable.isNotEmpty)
            '${movable.length}개를 ${DateFormat('M월 d일').format(day)}로 옮겼어요',
          if (kept > 0) '반복하는 할 일 $kept개는 그대로 뒀어요',
        ].join(' · '),
      ),
    ),
  );
}

/// The todos in [ids], as they are now.
List<TodoItem> selectedTodos(WidgetRef ref, Set<String> ids) => [
  for (final t in ref.read(todosProvider).value ?? const <TodoItem>[])
    if (ids.contains(t.id)) t,
];

/// Drag a box with the mouse, starting anywhere outside a row, and every
/// row it touches is selected. A click on the empty space clears it.
/// Ctrl/Shift adds to what's already selected.
class MarqueeSelect extends ConsumerStatefulWidget {
  final Widget child;

  const MarqueeSelect({super.key, required this.child});

  @override
  ConsumerState<MarqueeSelect> createState() => _MarqueeSelectState();
}

class _MarqueeSelectState extends ConsumerState<MarqueeSelect> {
  static const _slop = 6.0;
  final _items = <String, BuildContext>{};
  Offset? _start;
  Rect? _box;
  Set<String> _base = const {};

  void _register(String id, BuildContext context) => _items[id] = context;
  void _unregister(String id, BuildContext context) {
    if (_items[id] == context) _items.remove(id);
  }

  Rect? _rectOf(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  bool _onARow(Offset global) =>
      _items.values.any((c) => _rectOf(c)?.contains(global) ?? false);

  void _down(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.mouse || e.buttons != kPrimaryButton) {
      return;
    }
    if (_onARow(e.position)) return;
    final keys = HardwareKeyboard.instance;
    _base = keys.isControlPressed || keys.isShiftPressed
        ? ref.read(selectedTodoIdsProvider)
        : const {};
    _start = e.position;
  }

  void _move(PointerMoveEvent e) {
    final start = _start;
    if (start == null) return;
    if (_box == null && (e.position - start).distance < _slop) return;
    // A todo's own drag (its handle) won the gesture.
    if (ref.read(draggingTodoIdProvider) != null) {
      _start = null;
      return;
    }
    final box = Rect.fromPoints(start, e.position);
    final hit = {
      for (final MapEntry(:key, :value) in _items.entries)
        if (_rectOf(value)?.overlaps(box) ?? false) key,
    };
    ref.read(selectedTodoIdsProvider.notifier).state = {..._base, ...hit};
    setState(() => _box = box);
  }

  void _up(PointerEvent e) {
    if (_start != null && _box == null && e is PointerUpEvent) {
      // A plain click on the empty space: let go of the selection.
      ref.read(selectedTodoIdsProvider.notifier).state = const {};
    }
    _start = null;
    if (_box != null) setState(() => _box = null);
  }

  @override
  Widget build(BuildContext context) {
    final box = _box;
    final me = context.findRenderObject();
    Rect? local;
    if (box != null && me is RenderBox && me.attached) {
      local = Rect.fromPoints(
        me.globalToLocal(box.topLeft),
        me.globalToLocal(box.bottomRight),
      );
    }
    return _MarqueeScope(
      state: this,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: Stack(
          children: [
            widget.child,
            if (local != null)
              Positioned.fromRect(
                rect: local,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: kAccentBlue.withValues(alpha: 0.12),
                      border: Border.all(color: kAccentBlue, width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MarqueeScope extends InheritedWidget {
  final _MarqueeSelectState state;

  const _MarqueeScope({required this.state, required super.child});

  @override
  bool updateShouldNotify(_MarqueeScope old) => false;
}

/// A row the box can select, by [id].
class MarqueeItem extends StatefulWidget {
  final String id;
  final Widget child;

  const MarqueeItem({super.key, required this.id, required this.child});

  @override
  State<MarqueeItem> createState() => _MarqueeItemState();
}

class _MarqueeItemState extends State<MarqueeItem> {
  _MarqueeSelectState? _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope?._unregister(widget.id, context);
    _scope = context.getInheritedWidgetOfExactType<_MarqueeScope>()?.state;
    _scope?._register(widget.id, context);
  }

  @override
  void didUpdateWidget(MarqueeItem old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      _scope?._unregister(old.id, context);
      _scope?._register(widget.id, context);
    }
  }

  @override
  void dispose() {
    _scope?._unregister(widget.id, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shown while todos are selected: move them all to another day, park them
/// in 보관함, or let go.
class TodoSelectionBar extends ConsumerWidget {
  /// The day the list shows, for "다음 날로".
  final DateTime? day;

  const TodoSelectionBar({super.key, required this.day});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(selectedTodoIdsProvider);
    if (ids.isEmpty) return const SizedBox.shrink();
    final day = this.day ?? DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Paper(
        small: true,
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Highlighted(
                color: Diary.highlight(context, kAccentBlue, 1.3),
                child: Text('${ids.length}개 선택'),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.redo, size: 18),
              label: const Text('다음 날로'),
              onPressed: () => moveTodosToDay(
                context,
                ref,
                selectedTodos(ref, ids),
                DateTime(day.year, day.month, day.day + 1),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: const Text('날짜 골라 옮기기'),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: day,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035, 12, 31),
                );
                if (picked == null || !context.mounted) return;
                await moveTodosToDay(
                  context,
                  ref,
                  selectedTodos(ref, ids),
                  picked,
                );
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.inventory_2_outlined, size: 18),
              label: const Text('보관함으로'),
              onPressed: () async {
                final todos = selectedTodos(ref, ids);
                final movable = [
                  for (final t in todos)
                    if (!t.isRepeating) t.id,
                ];
                ref.read(selectedTodoIdsProvider.notifier).state = const {};
                if (movable.isEmpty) return;
                await ref.read(firestoreServiceProvider)?.archiveTodos(movable);
              },
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: '선택 해제',
              onPressed: () =>
                  ref.read(selectedTodoIdsProvider.notifier).state = const {},
            ),
          ],
        ),
      ),
    );
  }
}
