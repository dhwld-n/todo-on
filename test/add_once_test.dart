import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_on/models/category.dart';
import 'package:todo_on/models/habit.dart';
import 'package:todo_on/models/todo_item.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/services/firestore_service.dart';
import 'package:todo_on/widgets/add_todo_sheet.dart';
import 'package:todo_on/widgets/manage_categories_sheet.dart';
import 'package:todo_on/widgets/manage_habits_sheet.dart';

/// A server that takes its time to confirm a write, like a slow network.
class _SlowService extends Fake implements FirestoreService {
  final server = Completer<void>();
  final added = <Object>[];

  Future<void> _add(Object item) {
    added.add(item);
    return server.future;
  }

  @override
  Future<void> addTodo(TodoItem todo) => _add(todo);
  @override
  Future<void> addCategory(TodoCategory category) => _add(category);
  @override
  Future<void> addHabit(Habit habit) => _add(habit);
}

Future<_SlowService> _pump(WidgetTester tester, Widget sheet) async {
  await initializeDateFormatting('ko_KR');
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final service = _SlowService();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firestoreServiceProvider.overrideWithValue(service),
        categoriesProvider.overrideWith((ref) => Stream.value(const [])),
        habitsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: MaterialApp(home: Scaffold(body: sheet)),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

/// Types a name, mashes the button three times before the server answers,
/// then lets it answer.
Future<void> _mash(
  WidgetTester tester,
  _SlowService service,
  String button,
) async {
  await tester.enterText(find.byType(TextField).first, '운동');
  for (var i = 0; i < 3; i++) {
    await tester.tap(find.text(button), warnIfMissed: false);
    await tester.pump();
  }
  expect(service.added, hasLength(1));
  // Greyed out while saving.
  expect(
    tester
        .widget<FilledButton>(
          find.ancestor(
            of: find.text(button),
            matching: find.byType(FilledButton),
          ),
        )
        .onPressed,
    isNull,
  );
  service.server.complete();
  await tester.pumpAndSettle();
  expect(service.added, hasLength(1));
}

void main() {
  testWidgets('adding a todo: many presses, one todo', (tester) async {
    final service = await _pump(tester, const AddEditTodoSheet());
    await _mash(tester, service, '추가');
  });

  testWidgets('adding a category: many presses, one category', (tester) async {
    final service = await _pump(tester, const ManageCategoriesSheet());
    await _mash(tester, service, '카테고리 추가');
    // Usable again for the next one once the first is saved.
    await tester.enterText(find.byType(TextField).first, '공부');
    await tester.tap(find.text('카테고리 추가'));
    await tester.pump();
    expect(service.added, hasLength(2));
  });

  testWidgets('adding a habit: many presses, one habit', (tester) async {
    final service = await _pump(tester, const ManageHabitsSheet());
    // The habit sheet's first field is the emoji; the name comes next.
    await tester.enterText(find.byType(TextField).at(1), '운동');
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('습관 추가'), warnIfMissed: false);
      await tester.pump();
    }
    expect(service.added, hasLength(1));
    service.server.complete();
    await tester.pumpAndSettle();
    expect(service.added, hasLength(1));
  });
}
