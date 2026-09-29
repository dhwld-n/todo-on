import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/screens/home_screen.dart';
import 'package:todo_on/widgets/settings_dialog.dart';

Future<ProviderContainer> _pumpHome(
  WidgetTester tester, {
  required Size size,
  required bool isAndroid,
  double textScale = 1.0,
  ContentMode mode = ContentMode.todo,
  bool calendarExpanded = false,
}) async {
  await initializeDateFormatting('ko_KR');
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(null)),
      userProfileProvider.overrideWith((ref) => Stream.value(null)),
      firestoreServiceProvider.overrideWithValue(null),
      updateInfoProvider.overrideWith((ref) => Future.value(null)),
      isAndroidPlatformProvider.overrideWithValue(isAndroid),
      mobileCalendarExpandedProvider.overrideWith((ref) => calendarExpanded),
      contentModeProvider.overrideWith((ref) => mode),
      textScaleProvider.overrideWith((ref) => textScale),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      // Same scaling the real app applies in main.dart's builder.
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(ref.watch(textScaleProvider)),
            ),
            child: child!,
          ),
          home: const HomeScreen(),
        ),
      ),
    ),
  );
  // Not pumpAndSettle: the app bar's BlinkingDot repeats forever.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return container;
}

void main() {
  testWidgets('the gear opens 설정, and the slider resizes text and is saved', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = await _pumpHome(
      tester,
      size: const Size(360, 780),
      isAndroid: true,
    );
    final before = tester.getSize(find.text('TODO on')).height;

    await tester.tap(find.byTooltip('설정'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('글자 크기'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    // All the way right = the largest size.
    final slider = find.byType(Slider);
    await tester.tapAt(tester.getTopRight(slider) + const Offset(-4, 20));
    await tester.pump();
    expect(container.read(textScaleProvider), kMaxTextScale);
    expect(find.text('130%'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('textScale'), kMaxTextScale);
    expect(tester.getSize(find.text('TODO on')).height, greaterThan(before));

    await tester.tap(find.text('기본 크기로'));
    await tester.pump();
    expect(container.read(textScaleProvider), 1.0);
    expect(prefs.getDouble('textScale'), 1.0);
  });

  // The largest setting must not break any screen's layout.
  for (final (name, size, isAndroid) in [
    ('phone', const Size(360, 780), true),
    ('desktop', const Size(1280, 800), false),
  ]) {
    for (final mode in ContentMode.values) {
      testWidgets('130% text fits the $name ${mode.name} screen', (
        tester,
      ) async {
        await _pumpHome(
          tester,
          size: size,
          isAndroid: isAndroid,
          textScale: kMaxTextScale,
          mode: mode,
        );
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('130% text fits the $name calendar', (tester) async {
      await _pumpHome(
        tester,
        size: size,
        isAndroid: isAndroid,
        textScale: kMaxTextScale,
        calendarExpanded: true,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
