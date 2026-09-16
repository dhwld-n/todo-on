import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Todo Mate'))));
    expect(find.text('Todo Mate'), findsOneWidget);
  });
}
