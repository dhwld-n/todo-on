import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_on/models/dday.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/services/firestore_service.dart';
import 'package:todo_on/widgets/dday_banner.dart';

class _FakeService extends Fake implements FirestoreService {
  List<Dday>? saved;

  @override
  Future<void> saveDdays(List<Dday> ddays) async => saved = ddays;
}

Future<void> _pump(
  WidgetTester tester,
  Map<String, dynamic>? profile, {
  FirestoreService? service,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firestoreServiceProvider.overrideWithValue(service),
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

  Map<String, dynamic> several(DateTime now) => {
    'ddays': [
      Dday(
        id: 'a',
        label: '시험',
        date: now.add(const Duration(days: 7)),
      ).toMap(),
      Dday(
        id: 'b',
        label: '여행',
        date: now.add(const Duration(days: 30)),
      ).toMap(),
    ],
  };

  testWidgets('several D-days all show, nearest first, and more can be added', (
    tester,
  ) async {
    await _pump(tester, several(DateTime.now()));
    expect(find.text('D-7'), findsOneWidget);
    expect(find.text('D-30'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('시험')).dy,
      lessThan(tester.getTopLeft(find.text('여행')).dy),
    );
    expect(find.text('디데이 추가'), findsOneWidget);
    // Centered under the list, not tucked into the left corner.
    expect(
      tester.getCenter(find.byType(OutlinedButton)).dx,
      moreOrLessEquals(tester.getCenter(find.byType(Scaffold)).dx, epsilon: 1),
    );
  });

  testWidgets('adding one keeps the others', (tester) async {
    final service = _FakeService();
    await _pump(tester, several(DateTime.now()), service: service);
    await tester.tap(find.text('디데이 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '생일');
    await tester.pump();
    await tester.tap(find.text('날짜 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // test app isn't localized
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(service.saved!.map((d) => d.label), ['시험', '여행', '생일']);
  });

  testWidgets('editing or deleting one leaves the others alone', (
    tester,
  ) async {
    final service = _FakeService();
    await _pump(tester, several(DateTime.now()), service: service);
    await tester.tap(find.text('여행'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '제주 여행');
    await tester.pump();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(service.saved!.map((d) => d.label), ['시험', '제주 여행']);
    expect(service.saved!.map((d) => d.id), ['a', 'b']);

    await tester.tap(find.text('시험'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(service.saved!.map((d) => d.label), ['여행']);
  });

  testWidgets('a D-day from the old single-D-day format is kept on save', (
    tester,
  ) async {
    final service = _FakeService();
    await _pump(
      tester,
      _profile('수능', DateTime.now().add(const Duration(days: 3))),
      service: service,
    );
    await tester.tap(find.text('디데이 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '방학');
    await tester.pump();
    await tester.tap(find.text('날짜 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // test app isn't localized
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(service.saved!.map((d) => d.label), containsAll(['수능', '방학']));
  });
}
