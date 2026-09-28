import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/widgets/dday_banner.dart';

Future<void> _pump(WidgetTester tester, Map<String, dynamic>? profile) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firestoreServiceProvider.overrideWithValue(null),
        profileDocProvider.overrideWith((ref) => Stream.value(profile)),
      ],
      child: const MaterialApp(home: Scaffold(body: DdayBanner())),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> _profile(String label, DateTime date) => {
  'ddayLabel': label,
  'ddayDate': Timestamp.fromDate(date),
};

void main() {
  testWidgets('no dday set shows an add button', (tester) async {
    await _pump(tester, null);
    expect(find.text('디데이 추가'), findsOneWidget);
  });

  testWidgets('future date shows D-N', (tester) async {
    final target = DateTime.now().add(const Duration(days: 10));
    await _pump(tester, _profile('수능', target));
    expect(find.text('수능'), findsOneWidget);
    expect(find.text('D-10'), findsOneWidget);
  });

  testWidgets('today shows D-Day', (tester) async {
    await _pump(tester, _profile('오늘', DateTime.now()));
    expect(find.text('D-Day'), findsOneWidget);
  });

  testWidgets('past date shows D+N', (tester) async {
    final target = DateTime.now().subtract(const Duration(days: 5));
    await _pump(tester, _profile('지난 일', target));
    expect(find.text('D+5'), findsOneWidget);
  });

  testWidgets('tapping the add button opens the edit dialog', (tester) async {
    await _pump(tester, null);
    await tester.tap(find.text('디데이 추가'));
    await tester.pumpAndSettle();
    expect(find.text('디데이 설정'), findsOneWidget);
    // No existing dday, so there's nothing to delete yet.
    expect(find.text('삭제'), findsNothing);
  });

  testWidgets('tapping an existing dday opens the dialog with delete', (
    tester,
  ) async {
    final target = DateTime.now().add(const Duration(days: 3));
    await _pump(tester, _profile('수능', target));
    await tester.tap(find.text('수능'));
    await tester.pumpAndSettle();
    expect(find.text('디데이 설정'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);
  });
}
