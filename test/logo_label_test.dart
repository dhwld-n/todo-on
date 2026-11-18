import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:todo_on/models/category.dart';
import 'package:todo_on/providers/providers.dart';
import 'package:todo_on/screens/home_screen.dart';
import 'package:todo_on/theme/app_theme.dart';

void main() {
  testWidgets(
    'the logo sits on paper only while the rail is scrolled under it',
    (tester) async {
      await initializeDateFormatting('ko_KR');
      tester.view.physicalSize = const Size(1100, 460);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            userProfileProvider.overrideWith((ref) => Stream.value(null)),
            firestoreServiceProvider.overrideWithValue(null),
            updateInfoProvider.overrideWith((ref) => Future.value(null)),
            isAndroidPlatformProvider.overrideWithValue(false),
            profileDocProvider.overrideWith((ref) => Stream.value(null)),
            categoriesProvider.overrideWith(
              (ref) => Stream.value(const <TodoCategory>[]),
            ),
            todosProvider.overrideWith((ref) => Stream.value(const [])),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      double label() => tester
          .widget<AnimatedOpacity>(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;
      expect(label(), 0);
      await tester.drag(find.text('보관함').first, const Offset(0, -40));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(label(), 1);

      await tester.drag(find.text('보관함').first, const Offset(0, 200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(label(), 0);
    },
  );
}
