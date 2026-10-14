import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_on/models/todo_item.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/services/firestore_service.dart';
import 'package:todo_on/widgets/add_todo_sheet.dart';
import 'package:todo_on/widgets/todo_tile.dart';

const _memo = '1. 연습문제 2번\n2. 3장 요약\n3. 내일 질문할 것 정리';

class _FakeService extends Fake implements FirestoreService {
  final added = <TodoItem>[];

  @override
  Future<void> addTodo(TodoItem todo) async => added.add(todo);
}

void main() {
  testWidgets('a todo shows every line of its memo, not just the first', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodoTile(
            todo: TodoItem(
              id: 't',
              title: '자구 배열 공부',
              categoryId: null,
              isDone: false,
              dueDate: null,
              createdAt: DateTime(2026),
              order: 0,
              note: _memo,
            ),
            category: null,
          ),
        ),
      ),
    );
    final memo = find.text(_memo);
    expect(memo, findsOneWidget);
    expect(tester.widget<Text>(memo).maxLines, isNull);
    // Three lines laid out, not one cut off with "…".
    final lineHeight = tester.getSize(find.text('자구 배열 공부')).height;
    expect(tester.getSize(memo).height, greaterThan(lineHeight * 1.5));
  });

  testWidgets('the memo field keeps its line breaks', (tester) async {
    await initializeDateFormatting('ko_KR');
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = _FakeService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreServiceProvider.overrideWithValue(service),
          categoriesProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(home: Scaffold(body: AddEditTodoSheet())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '자구 배열 공부');
    await tester.tap(find.text('메모 추가'));
    await tester.pump();

    final memoField = find.widgetWithText(TextField, '메모');
    // Enter makes a new line here rather than submitting.
    expect(
      tester.widget<TextField>(memoField).keyboardType,
      TextInputType.multiline,
    );
    await tester.enterText(memoField, _memo);
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    expect(service.added.single.note, _memo);
  });
}
