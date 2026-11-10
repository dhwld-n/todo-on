import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as widgets show debugOnRebuildDirtyWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/screens/home_screen.dart';
import 'package:todo_on/widgets/profile_header.dart';

// The soft keyboard slides in over many frames, each with a new bottom
// inset. The home screen under the todo sheet must not rebuild on every
// one of them (it re-laid-out and repainted every clay card, which made
// adding a todo stutter on Android).
void main() {
  testWidgets('the keyboard sliding in does not rebuild the home screen', (
    tester,
  ) async {
    await initializeDateFormatting('ko_KR');
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          userProfileProvider.overrideWith((ref) => Stream.value(null)),
          firestoreServiceProvider.overrideWithValue(null),
          updateInfoProvider.overrideWith((ref) => Future.value(null)),
          isAndroidPlatformProvider.overrideWithValue(true),
          mobileCalendarExpandedProvider.overrideWith((ref) => false),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ProfileHeader), findsOneWidget);

    var homeRebuilds = 0;
    widgets.debugOnRebuildDirtyWidget = (element, builtOnce) {
      if (element.widget is HomeScreen) homeRebuilds++;
    };
    addTearDown(() => widgets.debugOnRebuildDirtyWidget = null);

    for (final inset in [60.0, 140.0, 220.0, 300.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump();
    }
    expect(homeRebuilds, 0);
    // Typing still frees up room: the profile header steps aside.
    expect(find.byType(ProfileHeader), findsNothing);

    tester.view.resetViewInsets();
    await tester.pump();
    expect(find.byType(ProfileHeader), findsOneWidget);
  });
}
