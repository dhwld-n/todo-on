import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/category.dart';
import '../models/todo_item.dart';
import '../providers/providers.dart';
import '../services/theme_prefs.dart';
import '../widgets/add_todo_sheet.dart';
import '../widgets/blinking_dot.dart';
import '../widgets/calendar_sidebar.dart';
import '../widgets/diary_pane.dart';
import '../widgets/friends_pane.dart';
import '../widgets/habits_pane.dart';
import '../widgets/manage_categories_sheet.dart';
import '../widgets/profile_header.dart';
import '../widgets/todo_tile.dart';
import '../widgets/update_checker.dart';

const double _kCalendarBreakpoint = 700;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final isWide = MediaQuery.of(context).size.width >= _kCalendarBreakpoint;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final mode = ref.watch(contentModeProvider);
    final activeDate = selectedDate ?? DateTime.now();
    final calendarExpanded = ref.watch(mobileCalendarExpandedProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('TODO on', style: TextStyle(fontFamily: 'GriunGyuwon')),
            const SizedBox(width: 5),
            const BlinkingDot(size: 7),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            tooltip: isDark ? '다크 모드' : '라이트 모드',
            onPressed: () {
              final next = isDark ? ThemeMode.light : ThemeMode.dark;
              ref.read(themeModeProvider.notifier).state = next;
              saveCachedThemeMode(next);
              ref
                  .read(firestoreServiceProvider)
                  ?.saveThemeMode(next == ThemeMode.dark ? 'dark' : 'light');
            },
          ),
          if (!isWide)
            IconButton(
              icon: Icon(
                calendarExpanded
                    ? Icons.calendar_month
                    : Icons.calendar_month_outlined,
              ),
              tooltip: calendarExpanded ? '캘린더 접기' : '캘린더 펼치기',
              onPressed: () => ref
                  .read(mobileCalendarExpandedProvider.notifier)
                  .update((expanded) => !expanded),
            ),
          IconButton(
            icon: const Icon(Icons.sell_outlined),
            tooltip: '카테고리 관리',
            onPressed: () => showManageCategoriesSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _kCalendarBreakpoint;
            final contentCard = _DashboardCard(
              child: switch (mode) {
                ContentMode.diary => DiaryPane(date: activeDate),
                ContentMode.friends => const FriendsPane(),
                ContentMode.habits => const HabitsPane(),
                ContentMode.todo => const _TodoListPane(),
              },
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ModeTabRail(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const ProfileHeader(),
                          const SizedBox(height: 16),
                          _DashboardCard(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: const CalendarSidebar(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: contentCard),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ModeTabRail(),
                Expanded(
                  child: calendarExpanded
                      ? SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _DashboardCard(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: const CalendarSidebar(),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.7,
                                child: contentCard,
                              ),
                            ],
                          ),
                        )
                      : contentCard,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ModeTabRail extends ConsumerWidget {
  const _ModeTabRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(contentModeProvider);
    final updateInfo = ref.watch(updateInfoProvider).value;
    final updateSeen = ref.watch(updateSeenProvider);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          _ModeTabButton(
            icon: Icons.checklist_rtl,
            label: 'TODO',
            selected: mode == ContentMode.todo,
            onTap: () =>
                ref.read(contentModeProvider.notifier).state = ContentMode.todo,
          ),
          const SizedBox(height: 12),
          _ModeTabButton(
            icon: Icons.people_outline,
            label: '친구',
            selected: mode == ContentMode.friends,
            onTap: () => ref.read(contentModeProvider.notifier).state =
                ContentMode.friends,
          ),
          const SizedBox(height: 12),
          _ModeTabButton(
            icon: Icons.menu_book_outlined,
            label: '일기',
            selected: mode == ContentMode.diary,
            onTap: () => ref.read(contentModeProvider.notifier).state =
                ContentMode.diary,
          ),
          const SizedBox(height: 12),
          _ModeTabButton(
            icon: Icons.local_fire_department_outlined,
            label: '습관',
            selected: mode == ContentMode.habits,
            onTap: () => ref.read(contentModeProvider.notifier).state =
                ContentMode.habits,
          ),
          const SizedBox(height: 12),
          _ModeTabButton(
            icon: Icons.system_update_alt,
            label: '업데이트',
            selected: false,
            showBadge: updateInfo != null && !updateSeen,
            onTap: () {
              if (updateInfo == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('이미 최신 버전이에요')),
                );
                return;
              }
              ref.read(updateSeenProvider.notifier).state = true;
              showUpdateDialog(context, updateInfo);
            },
          ),
        ],
      ),
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool showBadge;

  const _ModeTabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? Colors.white : colorScheme.onSurfaceVariant,
                ),
                if (showBadge)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? colorScheme.primary : colorScheme.surface,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _DashboardCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}

class _TodoListPane extends ConsumerWidget {
  const _TodoListPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAsync = ref.watch(todosProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedDate = ref.watch(selectedDateProvider);

    return Column(
      children: [
        if (selectedDate != null)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.primaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.event,
                  size: 16,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('yyyy년 M월 d일').format(selectedDate),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: todosAsync.when(
            data: (todos) => categoriesAsync.when(
              data: (categories) {
                final filtered = todos.where((t) {
                  if (selectedDate == null) return true;
                  return t.dueDate != null &&
                      isSameDay(t.dueDate!, selectedDate);
                }).toList();

                final byCategory = <String?, List<TodoItem>>{};
                for (final t in filtered) {
                  (byCategory[t.categoryId] ??= []).add(t);
                }
                for (final list in byCategory.values) {
                  list.sort((a, b) => a.order.compareTo(b.order));
                }

                if (categories.isEmpty && byCategory.isEmpty) {
                  return Center(
                    child: Text(
                      '카테고리를 먼저 만들어주세요.\n카테고리 관리에서 추가할 수 있어요.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).disabledColor,
                      ),
                    ),
                  );
                }

                final sections = <_CategorySectionData>[
                  for (final c in categories)
                    _CategorySectionData(
                      category: c,
                      todos: byCategory[c.id] ?? const [],
                    ),
                  if ((byCategory[null] ?? const []).isNotEmpty)
                    _CategorySectionData(
                      category: null,
                      todos: byCategory[null]!,
                    ),
                ];

                return ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    for (final section in sections)
                      _CategorySection(
                        category: section.category,
                        todos: section.todos,
                        selectedDate: selectedDate,
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
          ),
        ),
      ],
    );
  }
}

class _CategorySectionData {
  final TodoCategory? category;
  final List<TodoItem> todos;

  const _CategorySectionData({required this.category, required this.todos});
}

void _moveTodo(
  WidgetRef ref,
  TodoItem dragged,
  TodoCategory? destinationCategory,
  List<TodoItem> destinationTodos, {
  String? beforeId,
}) {
  final list = [...destinationTodos]..removeWhere((t) => t.id == dragged.id);
  final index = beforeId == null
      ? list.length
      : list.indexWhere((t) => t.id == beforeId);
  list.insert(index < 0 ? list.length : index, dragged);
  ref
      .read(firestoreServiceProvider)
      ?.moveTodo(
        todoId: dragged.id,
        categoryId: destinationCategory?.id,
        categoryIsPrivate: destinationCategory?.isPrivate ?? false,
        destinationOrderedIds: [for (final t in list) t.id],
      );
}

class _CategorySection extends ConsumerWidget {
  final TodoCategory? category;
  final List<TodoItem> todos;
  final DateTime? selectedDate;

  const _CategorySection({
    required this.category,
    required this.todos,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = category != null ? Color(category!.colorValue) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DragTarget<TodoItem>(
          onAcceptWithDetails: (details) =>
              _moveTodo(ref, details.data, category, todos),
          builder: (context, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:
                    color?.withValues(alpha: 0.14) ??
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                border: isHovering
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      )
                    : null,
              ),
              child: Row(
                children: [
                  if (color != null) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      category?.name ?? '카테고리 없음',
                      style: const TextStyle(
                        fontFamily: 'OwnglyphParkDaHyun',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (category?.isPrivate ?? false) ...[
                    Icon(
                      Icons.lock_outline,
                      size: 14,
                      color: Theme.of(context).disabledColor,
                    ),
                    const SizedBox(width: 4),
                  ],
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => showAddEditTodoSheet(
                      context,
                      ref,
                      initialDate: selectedDate,
                      initialCategoryId: category?.id,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (todos.isEmpty)
          DragTarget<TodoItem>(
            onAcceptWithDetails: (details) =>
                _moveTodo(ref, details.data, category, todos),
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: isHovering
                    ? BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
                child: Text(
                  '할 일이 없어요.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).disabledColor,
                  ),
                ),
              );
            },
          )
        else
          for (final todo in todos)
            DragTarget<TodoItem>(
              onWillAcceptWithDetails: (details) => details.data.id != todo.id,
              onAcceptWithDetails: (details) => _moveTodo(
                ref,
                details.data,
                category,
                todos,
                beforeId: todo.id,
              ),
              builder: (context, candidateData, rejectedData) {
                final isHovering = candidateData.isNotEmpty;
                return Container(
                  decoration: isHovering
                      ? BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        )
                      : null,
                  child: TodoTile(
                    key: ValueKey(todo.id),
                    todo: todo,
                    category: category,
                    onToggle: (v) => ref
                        .read(firestoreServiceProvider)
                        ?.setDone(todo.id, v ?? false),
                    onTap: () =>
                        showAddEditTodoSheet(context, ref, existing: todo),
                    onDelete: () =>
                        ref.read(firestoreServiceProvider)?.deleteTodo(todo.id),
                    dragHandle: Draggable<TodoItem>(
                      data: todo,
                      feedback: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 220),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            todo.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      childWhenDragging: Icon(
                        Icons.drag_indicator,
                        color: Theme.of(context).disabledColor,
                      ),
                      child: const Icon(Icons.drag_indicator),
                    ),
                  ),
                );
              },
            ),
        if (todos.isNotEmpty)
          DragTarget<TodoItem>(
            onAcceptWithDetails: (details) =>
                _moveTodo(ref, details.data, category, todos),
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;
              return Container(
                height: 12,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                decoration: isHovering
                    ? BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      )
                    : null,
              );
            },
          ),
      ],
    );
  }
}
