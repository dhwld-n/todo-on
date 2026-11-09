import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/category.dart';
import '../models/todo_item.dart';
import '../providers/providers.dart';
import '../services/theme_prefs.dart';
import '../theme/app_theme.dart';
import '../widgets/add_todo_sheet.dart';
import '../widgets/archive_pane.dart';
import '../widgets/blinking_dot.dart';
import '../widgets/calendar_sidebar.dart';
import '../widgets/chat_list_pane.dart';
import '../widgets/clay.dart';
import '../widgets/dday_banner.dart';
import '../widgets/diary_pane.dart';
import '../widgets/friends_pane.dart';
import '../widgets/habits_pane.dart';
import '../widgets/manage_categories_sheet.dart';
import '../widgets/profile_header.dart';
import '../widgets/settings_dialog.dart';
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
    final isAndroid = ref.watch(isAndroidPlatformProvider);
    // Read here, above the Scaffold: it strips the keyboard inset out of the
    // MediaQuery its body sees.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      bottomNavigationBar: isAndroid ? const _ModeBottomNav() : null,
      appBar: AppBar(
        // Shrinks rather than overflows when a phone's action icons and a
        // big 설정 font size leave it little room.
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'TODO on',
                style: TextStyle(fontFamily: 'GriunGyuwon'),
              ),
              const SizedBox(width: 5),
              const BlinkingDot(size: 7, color: kClayYellow),
            ],
          ),
        ),
        actions: [
          for (final (icon, tooltip, onPressed) in [
            (
              isDark ? Icons.dark_mode : Icons.light_mode,
              isDark ? '다크 모드' : '라이트 모드',
              () {
                final next = isDark ? ThemeMode.light : ThemeMode.dark;
                ref.read(themeModeProvider.notifier).state = next;
                saveCachedThemeMode(next);
                ref
                    .read(firestoreServiceProvider)
                    ?.saveThemeMode(next == ThemeMode.dark ? 'dark' : 'light');
              },
            ),
            if (!isWide && mode == ContentMode.todo)
              (
                calendarExpanded
                    ? Icons.calendar_month
                    : Icons.calendar_month_outlined,
                calendarExpanded ? '목록으로 보기' : '캘린더로 보기',
                () => ref
                    .read(mobileCalendarExpandedProvider.notifier)
                    .update((expanded) => !expanded),
              ),
            (
              Icons.sell_outlined,
              '카테고리 관리',
              () => showManageCategoriesSheet(context),
            ),
            (Icons.settings_outlined, '설정', () => showSettingsDialog(context)),
            (
              Icons.logout,
              '로그아웃',
              () => ref.read(authServiceProvider).signOut(),
            ),
          ])
            Padding(
              padding: EdgeInsets.only(right: isWide ? 12 : 8),
              child: ClayIconButton(
                icon: icon,
                tooltip: tooltip,
                onPressed: onPressed,
                size: isWide ? 42 : 36,
                iconSize: isWide ? 20 : 17,
              ),
            ),
          const SizedBox(width: 4),
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
                ContentMode.addFriend => const AddFriendPane(),
                ContentMode.archive => const ArchivePane(),
                ContentMode.habits => const HabitsPane(),
                ContentMode.chat => const ChatListPane(),
                ContentMode.todo => const _TodoListPane(),
              },
            );
            if (isAndroid) {
              final showCalendarFirst =
                  mode == ContentMode.todo && calendarExpanded;
              // With the soft keyboard up there's barely room for the
              // input itself - drop the profile header while typing.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!keyboardOpen) ...[
                    const ProfileHeader(),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: showCalendarFirst
                        ? _DashboardCard(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: CalendarSidebar(
                              onDaySelected: (_) => _showDayTodosSheet(context),
                            ),
                          )
                        : contentCard,
                  ),
                ],
              );
            }
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ModeTabRail(),
                  Expanded(
                    child: SingleChildScrollView(
                      // Room inside the scroll view's clip for the cards'
                      // clay shadows, which fall to the right and below.
                      padding: const EdgeInsets.fromLTRB(0, 0, 14, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const ProfileHeader(),
                          const SizedBox(height: 20),
                          _DashboardCard(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: const CalendarSidebar(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(flex: 2, child: contentCard),
                ],
              );
            }
            final showCalendarFirst =
                mode == ContentMode.todo && calendarExpanded;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ModeTabRail(),
                Expanded(
                  child: showCalendarFirst
                      ? _DashboardCard(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: CalendarSidebar(
                            onDaySelected: (_) => _showDayTodosSheet(context),
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

void _showDayTodosSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).disabledColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _TodoListPane(
                scrollController: controller,
                swipeBetweenDays: true,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ModeTabRail extends ConsumerWidget {
  const _ModeTabRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(contentModeProvider);
    final updateInfo = ref.watch(updateInfoProvider).value;
    final updateSeen = ref.watch(updateSeenProvider);
    // Scrolls in a short window rather than running off the bottom; no
    // clip, so the buttons' shadows aren't cut at the rail's edges.
    return SingleChildScrollView(
      clipBehavior: Clip.none,
      padding: const EdgeInsets.fromLTRB(0, 0, 20, 16),
      child: Column(
        children: [
          _ModeTabButton(
            icon: Icons.checklist_rtl,
            label: 'TODO',
            selected: mode == ContentMode.todo,
            onTap: () =>
                ref.read(contentModeProvider.notifier).state = ContentMode.todo,
          ),
          const SizedBox(height: 14),
          _ModeTabButton(
            icon: Icons.inventory_2_outlined,
            label: '보관함',
            selected: mode == ContentMode.archive,
            onTap: () => ref.read(contentModeProvider.notifier).state =
                ContentMode.archive,
          ),
          const SizedBox(height: 14),
          _ModeTabButton(
            icon: Icons.people_outline,
            label: '친구',
            selected: mode == ContentMode.friends,
            onTap: () => ref.read(contentModeProvider.notifier).state =
                ContentMode.friends,
          ),
          const SizedBox(height: 14),
          _ModeTabButton(
            icon: Icons.person_add_alt_outlined,
            label: '친구 추가',
            selected: mode == ContentMode.addFriend,
            onTap: () => ref.read(contentModeProvider.notifier).state =
                ContentMode.addFriend,
          ),
          const SizedBox(height: 14),
          _ModeTabButton(
            icon: Icons.chat_bubble_outline,
            label: '채팅',
            selected: mode == ContentMode.chat,
            showBadge: ref.watch(hasUnreadChatProvider),
            onTap: () =>
                ref.read(contentModeProvider.notifier).state = ContentMode.chat,
          ),
          const SizedBox(height: 14),
          _ModeTabButton(
            icon: Icons.menu_book_outlined,
            label: '일기',
            selected: mode == ContentMode.diary,
            showBadge: ref.watch(hasUnseenSharedDiaryProvider),
            onTap: () => ref.read(contentModeProvider.notifier).state =
                ContentMode.diary,
          ),
          const SizedBox(height: 14),
          _ModeTabButton(
            icon: Icons.local_fire_department_outlined,
            label: '습관',
            selected: mode == ContentMode.habits,
            onTap: () => ref.read(contentModeProvider.notifier).state =
                ContentMode.habits,
          ),
          const SizedBox(height: 14),
          _ModeTabButton(
            icon: Icons.system_update_alt,
            label: '업데이트',
            selected: false,
            showBadge: updateInfo != null && !updateSeen,
            onTap: () async {
              // The startup check can be stale if a release came out while
              // the app was open, so check again on every tap.
              final info = await ref.refresh(updateInfoProvider.future);
              if (!context.mounted) return;
              if (info == null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('이미 최신 버전이에요')));
                return;
              }
              ref.read(updateSeenProvider.notifier).state = true;
              showUpdateDialog(context, info);
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
    return Clay(
      small: true,
      radius: 22,
      width: 64,
      color: selected ? kClayBlue : null,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      size: 22,
                      color: selected
                          ? Colors.white
                          : colorScheme.onSurfaceVariant,
                    ),
                    if (showBadge)
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: kClayPurple,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? kClayBlue : colorScheme.surface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeBottomNav extends ConsumerWidget {
  const _ModeBottomNav();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(contentModeProvider);
    final updateInfo = ref.watch(updateInfoProvider).value;
    final updateSeen = ref.watch(updateSeenProvider);
    return SafeArea(
      top: false,
      child: Clay(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
        child: Row(
          children: [
            Expanded(
              child: _ModeNavItem(
                icon: Icons.checklist_rtl,
                label: 'TODO',
                selected: mode == ContentMode.todo,
                onTap: () => ref.read(contentModeProvider.notifier).state =
                    ContentMode.todo,
              ),
            ),
            Expanded(
              child: _ModeNavItem(
                icon: Icons.inventory_2_outlined,
                label: '보관함',
                selected: mode == ContentMode.archive,
                onTap: () => ref.read(contentModeProvider.notifier).state =
                    ContentMode.archive,
              ),
            ),
            Expanded(
              child: _ModeNavItem(
                icon: Icons.people_outline,
                label: '친구',
                selected: mode == ContentMode.friends,
                onTap: () => ref.read(contentModeProvider.notifier).state =
                    ContentMode.friends,
              ),
            ),
            Expanded(
              child: _ModeNavItem(
                icon: Icons.person_add_alt_outlined,
                label: '친구 추가',
                selected: mode == ContentMode.addFriend,
                onTap: () => ref.read(contentModeProvider.notifier).state =
                    ContentMode.addFriend,
              ),
            ),
            Expanded(
              child: _ModeNavItem(
                icon: Icons.chat_bubble_outline,
                label: '채팅',
                selected: mode == ContentMode.chat,
                showBadge: ref.watch(hasUnreadChatProvider),
                onTap: () => ref.read(contentModeProvider.notifier).state =
                    ContentMode.chat,
              ),
            ),
            Expanded(
              child: _ModeNavItem(
                icon: Icons.menu_book_outlined,
                label: '일기',
                selected: mode == ContentMode.diary,
                showBadge: ref.watch(hasUnseenSharedDiaryProvider),
                onTap: () => ref.read(contentModeProvider.notifier).state =
                    ContentMode.diary,
              ),
            ),
            Expanded(
              child: _ModeNavItem(
                icon: Icons.local_fire_department_outlined,
                label: '습관',
                selected: mode == ContentMode.habits,
                onTap: () => ref.read(contentModeProvider.notifier).state =
                    ContentMode.habits,
              ),
            ),
            Expanded(
              child: _ModeNavItem(
                icon: Icons.system_update_alt,
                label: '업데이트',
                selected: false,
                showBadge: updateInfo != null && !updateSeen,
                onTap: () async {
                  // The startup check can be stale if a release came out
                  // while the app was open, so check again on every tap.
                  final info = await ref.refresh(updateInfoProvider.future);
                  if (!context.mounted) return;
                  if (info == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('이미 최신 버전이에요')),
                    );
                    return;
                  }
                  ref.read(updateSeenProvider.notifier).state = true;
                  showUpdateDialog(context, info);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool showBadge;

  const _ModeNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconWidget = Icon(
      icon,
      size: 19,
      color: selected ? Colors.white : colorScheme.onSurfaceVariant,
    );
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // The selected tab's icon sits on a blue clay pill.
                selected
                    ? Clay(
                        small: true,
                        radius: 14,
                        color: kClayBlue,
                        width: 38,
                        height: 32,
                        child: Center(child: iconWidget),
                      )
                    : SizedBox(
                        width: 38,
                        height: 32,
                        child: Center(child: iconWidget),
                      ),
                if (showBadge)
                  Positioned(
                    right: 2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: kClayPurple,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.surface,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: selected
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
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
    return Clay(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}

class _TodoListPane extends ConsumerWidget {
  final ScrollController? scrollController;

  /// In the day sheet the day's list moves like a page: swipe left for the
  /// next day, right for the day before. A todo's own swipe-to-delete is
  /// off there; deleting goes through its edit sheet instead.
  final bool swipeBetweenDays;

  const _TodoListPane({this.scrollController, this.swipeBetweenDays = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const DdayBanner(),
        Expanded(
          child: swipeBetweenDays
              ? _DaySwiper(scrollController: scrollController)
              : _DayTodos(
                  date: ref.watch(selectedDateProvider),
                  scrollController: scrollController,
                ),
        ),
      ],
    );
  }
}

/// Days as pages that follow the finger, like turning a planner's pages.
class _DaySwiper extends ConsumerStatefulWidget {
  final ScrollController? scrollController;

  const _DaySwiper({this.scrollController});

  @override
  ConsumerState<_DaySwiper> createState() => _DaySwiperState();
}

class _DaySwiperState extends ConsumerState<_DaySwiper> {
  // Page [_origin] is the day the sheet opened on; there's room either way.
  static const _origin = 100000;
  late final DateTime _base;
  final _pages = PageController(initialPage: _origin);
  var _page = _origin;

  @override
  void initState() {
    super.initState();
    final d = ref.read(selectedDateProvider) ?? DateTime.now();
    _base = DateTime(d.year, d.month, d.day);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  DateTime _dayAt(int page) =>
      DateTime(_base.year, _base.month, _base.day + page - _origin);

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pages,
      onPageChanged: (page) {
        setState(() => _page = page);
        final day = _dayAt(page);
        ref.read(selectedDateProvider.notifier).state = day;
        ref.read(focusedMonthProvider.notifier).state = day;
      },
      itemBuilder: (context, page) => _DayTodos(
        date: _dayAt(page),
        // The sheet's controller drives one list at a time: the page that's
        // showing. A page mid-swipe scrolls on its own.
        scrollController: page == _page ? widget.scrollController : null,
        swipeToDelete: false,
      ),
    );
  }
}

/// One day's todos under its date bar, by category; every todo when [date]
/// is null.
class _DayTodos extends ConsumerWidget {
  final DateTime? date;
  final ScrollController? scrollController;
  final bool swipeToDelete;

  const _DayTodos({
    required this.date,
    this.scrollController,
    this.swipeToDelete = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAsync = ref.watch(todosProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final date = this.date;

    return Column(
      children: [
        if (date != null)
          _DateBar(date: date),
        Expanded(
          child: todosAsync.when(
            data: (todos) => categoriesAsync.when(
              data: (categories) {
                final filtered = todos.where((t) {
                  if (date == null) return true;
                  return t.dueDate != null && isSameDay(t.dueDate!, date);
                }).toList();

                final byCategory = <String?, List<TodoItem>>{};
                for (final t in filtered) {
                  (byCategory[t.categoryId] ??= []).add(t);
                }
                for (final list in byCategory.values) {
                  list.sort(compareTodosForList);
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

                if (sections.length < 2) {
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      for (final section in sections)
                        _CategorySection(
                          category: section.category,
                          todos: section.todos,
                          selectedDate: date,
                          swipeToDelete: swipeToDelete,
                        ),
                    ],
                  );
                }
                // 2+ categories: lay them out as responsive columns instead of
                // one long stacked list, so wide windows aren't mostly empty
                // space. Falls back to a single column on narrow widths.
                return LayoutBuilder(
                  builder: (context, constraints) {
                    const minColumnWidth = 300.0;
                    const gap = 16.0;
                    final columns = (constraints.maxWidth / minColumnWidth)
                        .floor()
                        .clamp(1, sections.length);
                    final columnWidth =
                        (constraints.maxWidth - gap * (columns - 1)) / columns;
                    return SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final section in sections)
                            SizedBox(
                              width: columnWidth,
                              child: _CategorySection(
                                category: section.category,
                                todos: section.todos,
                                selectedDate: date,
                                swipeToDelete: swipeToDelete,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
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

/// The selected day, pressed into the card.
class _DateBar extends StatelessWidget {
  final DateTime date;

  const _DateBar({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Clay(
        depth: ClayDepth.inset,
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                DateFormat('yyyy년 M월 d일').format(date),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySectionData {
  final TodoCategory? category;
  final List<TodoItem> todos;

  const _CategorySectionData({required this.category, required this.todos});
}

/// [ids] with [draggedId] moved next to [targetId]: after it when
/// [after], else before it; to the end when there's no target.
@visibleForTesting
List<String> reorderedTodoIds(
  List<String> ids,
  String draggedId, {
  String? targetId,
  bool after = false,
}) {
  final list = [...ids]..remove(draggedId);
  final index = targetId == null ? -1 : list.indexOf(targetId);
  list.insert(index < 0 ? list.length : index + (after ? 1 : 0), draggedId);
  return list;
}

/// Hovering a row of the dragged todo's own category *below* it means "put
/// it after this one" - otherwise the spot right under the next row could
/// never be reached (it's where the todo already is). Anything else lands
/// above the hovered row.
bool _dropsAfter(TodoItem dragged, TodoItem hovered, List<TodoItem> todos) {
  final from = todos.indexWhere((t) => t.id == dragged.id);
  return from >= 0 && from < todos.indexWhere((t) => t.id == hovered.id);
}

void _moveTodo(
  WidgetRef ref,
  TodoItem dragged,
  TodoCategory? destinationCategory,
  List<TodoItem> destinationTodos, {
  String? targetId,
  bool after = false,
}) {
  final byId = {for (final t in destinationTodos) t.id: t, dragged.id: dragged};
  final list = [
    for (final id in reorderedTodoIds(
      [for (final t in destinationTodos) t.id],
      dragged.id,
      targetId: targetId,
      after: after,
    ))
      byId[id]!,
  ];
  ref
      .read(firestoreServiceProvider)
      ?.moveTodo(
        todoId: dragged.id,
        categoryId: destinationCategory?.id,
        categoryIsPrivate:
            (destinationCategory?.isPrivate ?? false) || dragged.isPrivate,
        destinationOrderedIds: [for (final t in list) t.id],
      );
}

/// Where a dragged todo will land - a clear box instead of a thin line.
class _DropSlot extends StatelessWidget {
  const _DropSlot();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      height: 52,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.12),
        border: Border.all(color: primary, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '여기에 놓여요',
        style: TextStyle(
          color: primary,
          fontWeight: FontWeight.w700,
          fontFamily: 'GriunFromsol',
        ),
      ),
    );
  }
}

/// The card that follows the pointer while a todo is dragged.
class _DragCard extends StatelessWidget {
  static const width = 300.0;
  static const height = 68.0;

  final TodoItem todo;

  const _DragCard({required this.todo});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          // Tinted so it doesn't blend into the list it's floating over.
          color: Color.alphaBlend(
            scheme.primary.withValues(alpha: 0.16),
            scheme.surface,
          ),
          border: Border.all(color: scheme.primary, width: 2),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            CatCheckbox(isDone: todo.isDone),
            const SizedBox(width: kTodoCheckboxGap),
            Expanded(
              child: Text(
                todo.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'GriunFromsol',
                  fontSize: kTodoTitleSize,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends ConsumerWidget {
  final TodoCategory? category;
  final List<TodoItem> todos;
  final DateTime? selectedDate;
  final bool swipeToDelete;

  const _CategorySection({
    required this.category,
    required this.todos,
    required this.selectedDate,
    this.swipeToDelete = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = category != null ? Color(category!.colorValue) : null;
    final draggingId = ref.watch(draggingTodoIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DragTarget<TodoItem>(
          onAcceptWithDetails: (details) =>
              _moveTodo(ref, details.data, category, todos),
          builder: (context, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;
            final surface = Theme.of(context).colorScheme.surface;
            final dark = Theme.of(context).brightness == Brightness.dark;
            final categoryColor = color ?? Theme.of(context).disabledColor;
            return Container(
              // Tight to its first todo, whose row starts higher too.
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              foregroundDecoration: isHovering
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    )
                  : null,
              child: Clay(
                small: true,
                radius: 22,
                // Tinted with the category's color, opaque so the clay's own
                // shading reads the same over any page. In the dark a light
                // tint turns muddy (yellow went olive), so it's a deep shade
                // of the color there, glowing faintly in it.
                color: dark
                    ? Color.lerp(categoryColor, kDarkBg, 0.68)
                    : Color.alphaBlend(
                        categoryColor.withValues(alpha: 0.16),
                        surface,
                      ),
                shadowColor: dark ? categoryColor : null,
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
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
                    ClayIconButton(
                      icon: Icons.add,
                      size: 32,
                      iconSize: 18,
                      onPressed: () => showAddEditTodoSheet(
                        context,
                        ref,
                        initialDate: selectedDate,
                        initialCategoryId: category?.id,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (todos.isEmpty)
          DragTarget<TodoItem>(
            onAcceptWithDetails: (details) =>
                _moveTodo(ref, details.data, category, todos),
            builder: (context, candidateData, rejectedData) {
              if (candidateData.isNotEmpty) return const _DropSlot();
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 16, 16),
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
                targetId: todo.id,
                after: _dropsAfter(details.data, todo, todos),
              ),
              builder: (context, candidateData, rejectedData) {
                final dragged = candidateData.firstOrNull;
                final after =
                    dragged != null && _dropsAfter(dragged, todo, todos);
                // The slot sits inside this target, so the pointer stays over
                // it after the tile shifts - no flicker while hovering.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (dragged != null && !after) const _DropSlot(),
                    Opacity(
                      opacity: todo.id == draggingId ? 0.35 : 1,
                      child: TodoTile(
                        key: ValueKey(todo.id),
                        todo: todo,
                        category: category,
                        onToggle: (v) => ref
                            .read(firestoreServiceProvider)
                            ?.setDone(todo, v ?? false),
                        onTap: () =>
                            showAddEditTodoSheet(context, ref, existing: todo),
                        onDelete: swipeToDelete
                            ? () => deleteTodoAsking(context, ref, todo)
                            : null,
                        dragHandle: Draggable<TodoItem>(
                          data: todo,
                          // Center the card on the pointer instead of hanging
                          // it off the handle at the row's right edge.
                          dragAnchorStrategy: (_, _, _) => const Offset(
                            _DragCard.width / 2,
                            _DragCard.height / 2,
                          ),
                          onDragStarted: () =>
                              ref.read(draggingTodoIdProvider.notifier).state =
                                  todo.id,
                          onDragEnd: (_) =>
                              ref.read(draggingTodoIdProvider.notifier).state =
                                  null,
                          feedback: _DragCard(todo: todo),
                          childWhenDragging: Icon(
                            Icons.drag_indicator,
                            color: Theme.of(context).disabledColor,
                          ),
                          child: const Icon(Icons.drag_indicator),
                        ),
                      ),
                    ),
                    if (after) const _DropSlot(),
                  ],
                );
              },
            ),
        if (todos.isNotEmpty)
          DragTarget<TodoItem>(
            onAcceptWithDetails: (details) =>
                _moveTodo(ref, details.data, category, todos),
            builder: (context, candidateData, rejectedData) {
              if (candidateData.isNotEmpty) return const _DropSlot();
              return const SizedBox(height: 6);
            },
          ),
      ],
    );
  }
}
