import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/screens/home_screen.dart';

List<Override> _overrides({required bool isAndroid}) => [
  authStateProvider.overrideWith((ref) => Stream.value(null)),
  userProfileProvider.overrideWith((ref) => Stream.value(null)),
  firestoreServiceProvider.overrideWithValue(null),
  updateInfoProvider.overrideWith((ref) => Future.value(null)),
  isAndroidPlatformProvider.overrideWithValue(isAndroid),
  mobileCalendarExpandedProvider.overrideWith((ref) => false),
];

Future<ProviderContainer> _pumpHome(
  WidgetTester tester, {
  required bool isAndroid,
}) async {
  final container = ProviderContainer(
    overrides: _overrides(isAndroid: isAndroid),
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  // Not pumpAndSettle: the app bar's BlinkingDot repeats forever.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return container;
}

void main() {
  testWidgets('Android layout shows a bottom nav bar, not the side rail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpHome(tester, isAndroid: true);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.bottomNavigationBar, isNotNull);
    // All six tabs are reachable from the bottom bar.
    for (final label in ['TODO', '친구', '채팅', '일기', '습관', '업데이트']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('desktop/narrow layout has no bottom nav bar', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpHome(tester, isAndroid: false);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.bottomNavigationBar, isNull);
  });

  testWidgets('tapping a bottom nav tab switches the content mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final container = await _pumpHome(tester, isAndroid: true);
    expect(container.read(contentModeProvider), ContentMode.todo);

    await tester.tap(find.text('습관'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(container.read(contentModeProvider), ContentMode.habits);
  });
}
