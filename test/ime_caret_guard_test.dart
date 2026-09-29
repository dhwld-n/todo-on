import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_on/widgets/ime_caret_guard.dart';

void main() {
  testWidgets('the caret hides while a syllable is composing, and only then', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ImeCaretGuard(child: child!),
        home: Scaffold(body: TextField(controller: controller)),
      ),
    );
    Color caret() =>
        tester.widget<EditableText>(find.byType(EditableText)).cursorColor;

    await tester.tap(find.byType(TextField));
    await tester.pump();
    final normal = caret();
    expect(normal.a, greaterThan(0));

    // What Windows' Korean IME sends mid-syllable: "포커스 다" with "다"
    // still composing and the caret stuck at its start.
    const typed = '포커스 다';
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: typed,
        selection: TextSelection.collapsed(offset: typed.length - 1),
        composing: TextRange(start: typed.length - 1, end: typed.length),
      ),
    );
    await tester.pump();
    expect(caret().a, 0);
    // The text itself is untouched - only the caret's paint changed.
    expect(controller.text, typed);
    expect(controller.value.composing.isCollapsed, isFalse);

    // Syllable committed: caret at the end and visible again.
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: typed,
        selection: TextSelection.collapsed(offset: typed.length),
      ),
    );
    await tester.pump();
    expect(caret(), normal);
  });

  testWidgets('moving to another field follows that field instead', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ImeCaretGuard(child: child!),
        home: const Scaffold(
          body: Column(
            children: [
              TextField(key: Key('a')),
              TextField(key: Key('b')),
            ],
          ),
        ),
      ),
    );
    Color caretOf(String key) => tester
        .widget<EditableText>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(EditableText),
          ),
        )
        .cursorColor;

    await tester.tap(find.byKey(const Key('a')));
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '다',
        selection: TextSelection.collapsed(offset: 0),
        composing: TextRange(start: 0, end: 1),
      ),
    );
    await tester.pump();
    expect(caretOf('a').a, 0);

    await tester.tap(find.byKey(const Key('b')));
    await tester.pump();
    expect(caretOf('b').a, greaterThan(0));
  });
}
