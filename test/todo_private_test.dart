import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_on/models/category.dart';
import 'package:todo_on/models/todo_item.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/services/firestore_service.dart';
import 'package:todo_on/widgets/add_todo_sheet.dart';
import 'package:todo_on/widgets/todo_tile.dart';

class _FakeService extends Fake implements FirestoreService {
  final added = <TodoItem>[];

  @override
  Future<void> addTodo(TodoItem todo) async => added.add(todo);
}

const _public = TodoCategory(id: 'pub', name: '공부', colorValue: 0, order: 0);
const _secret = TodoCategory(
  id: 'sec',
  name: '일기',
  colorValue: 0,
  order: 1,
  isPrivate: true,
);

Future<_FakeService> _pump(WidgetTester tester, String categoryId) async {
  await initializeDateFormatting('ko_KR');
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final service = _FakeService();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firestoreServiceProvider.overrideWithValue(service),
        categoriesProvider.overrideWith(
          (ref) => Stream.value(const [_public, _secret]),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(body: AddEditTodoSheet(initialCategoryId: categoryId)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

void main() {
  testWidgets('a single todo can be hidden from friends', (tester) async {
    final service = await _pump(tester, 'pub');
    await tester.enterText(find.byType(TextField).first, '비밀 선물 사기');
    await tester.tap(find.text('나만 보기'));
    await tester.pump();
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    final todo = service.added.single;
    expect(todo.isPrivate, isTrue);
    // Friends' query and the security rules only look at this field.
    expect(todo.toFirestore()['categoryIsPrivate'], isTrue);
  });

  testWidgets('left off, the todo stays visible to friends', (tester) async {
    final service = await _pump(tester, 'pub');
    await tester.enterText(find.byType(TextField).first, '영어 단어');
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    expect(service.added.single.toFirestore()['categoryIsPrivate'], isFalse);
  });

  testWidgets('in a private category it is already hidden', (tester) async {
    await _pump(tester, 'sec');
    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.value, isTrue);
    expect(toggle.onChanged, isNull);
  });

  testWidgets('a private todo shows a lock', (tester) async {
    TodoTile tile(bool isPrivate) => TodoTile(
      todo: TodoItem(
        id: 't',
        title: '비밀 선물 사기',
        categoryId: null,
        isDone: false,
        dueDate: null,
        createdAt: DateTime(2026),
        order: 0,
        isPrivate: isPrivate,
      ),
      category: null,
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: tile(true))));
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: tile(false))));
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });
}
