import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_on/models/category.dart';
import 'package:todo_on/models/todo_item.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/screens/home_screen.dart';
import 'package:todo_on/widgets/todo_search.dart';

TodoItem _todo(
  String id,
  String title,
  DateTime? day, {
  String? note,
  List<int> weekdays = const [],
}) => TodoItem(
  id: id,
  title: title,
  categoryId: 'school',
  isDone: false,
  dueDate: day,
  createdAt: DateTime(2026, 11, 1),
  order: 0,
  note: note,
  repeatWeekdays: weekdays,
);

void main() {
  final today = DateTime(2026, 11, 18);

  group('searchTodos', () {
    test('finds by title or memo, any case; nothing for a blank query', () {
      final todos = [
        _todo('a', 'Algorithm 2문제', today),
        _todo('b', '헬스', today, note: 'algorithm 책 챙기기'),
        _todo('c', '독서', today),
      ];
      expect(
        searchTodos(todos, 'ALGO', today).map((h) => h.todo.id),
        unorderedEquals(['a', 'b']),
      );
      expect(searchTodos(todos, '   ', today), isEmpty);
    });

    test('nearest day first, 보관함 last', () {
      final todos = [
        _todo('far', '과제', DateTime(2026, 12, 25)),
        _todo('archived', '과제', null),
        _todo('near', '과제', DateTime(2026, 11, 17)),
        _todo('soon', '과제', DateTime(2026, 11, 20)),
      ];
      expect(searchTodos(todos, '과제', today).map((h) => h.todo.id), [
        'near',
        'soon',
        'far',
        'archived',
      ]);
    });

    test('a repeat is found once, at its next day', () {
      final copies = [
        for (final d in [11, 16, 18, 23])
          _todo('r', '헬스', DateTime(2026, 11, d), weekdays: const [1, 3]),
      ];
      final hits = searchTodos(copies, '헬스', DateTime(2026, 11, 17));
      expect(hits, hasLength(1));
      expect(hits.single.day, DateTime(2026, 11, 18));
      // All past: its last day.
      final past = searchTodos(copies, '헬스', DateTime(2026, 12, 1));
      expect(past.single.day, DateTime(2026, 11, 23));
    });
  });

  testWidgets('search, then tap a result to go to its day', (tester) async {
    await initializeDateFormatting('ko_KR');
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        userProfileProvider.overrideWith((ref) => Stream.value(null)),
        firestoreServiceProvider.overrideWithValue(null),
        updateInfoProvider.overrideWith((ref) => Future.value(null)),
        isAndroidPlatformProvider.overrideWithValue(false),
        profileDocProvider.overrideWith((ref) => Stream.value(null)),
        selectedDateProvider.overrideWith((ref) => DateTime(2026, 11, 18)),
        categoriesProvider.overrideWith(
          (ref) => Stream.value(const [
            TodoCategory(
              id: 'school',
              name: 'SCHOOL',
              colorValue: 0xFF78909C,
              order: 0,
            ),
          ]),
        ),
        todosProvider.overrideWith(
          (ref) => Stream.value([
            _todo('a', '기말 과제 제출', DateTime(2026, 12, 3)),
            _todo('b', '헬스', DateTime(2026, 11, 18)),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byTooltip('할 일 찾기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField).last, '기말');
    await tester.pump();

    expect(find.text('12월 3일 (목)'), findsOneWidget);
    await tester.tap(find.text('12월 3일 (목)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(container.read(selectedDateProvider), DateTime(2026, 12, 3));
    // The calendar turns to that month (it hands back a UTC midnight).
    final month = container.read(focusedMonthProvider);
    expect((month.year, month.month), (2026, 12));
    expect(container.read(contentModeProvider), ContentMode.todo);
    expect(find.text('할 일 찾기'), findsNothing);
  });
}
