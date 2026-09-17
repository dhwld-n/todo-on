import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'providers/providers.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/firestore_service.dart';
import 'theme/app_theme.dart';
import 'widgets/update_checker.dart';

void _logCrash(Object error, StackTrace stack) {
  try {
    File('crash_log.txt').writeAsStringSync(
      '${DateTime.now()}\n$error\n$stack\n\n',
      mode: FileMode.append,
    );
  } catch (_) {}
}

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        _logCrash(details.exception, details.stack ?? StackTrace.current);
      };
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // Disable on-disk persistence: its native cache-lock file is the source of
      // the Windows crashes seen when a stale process still holds the lock.
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
      await initializeDateFormatting('ko_KR', null);
      runApp(const ProviderScope(child: TodoMateApp()));
    },
    (error, stack) {
      _logCrash(error, stack);
    },
  );
}

class TodoMateApp extends ConsumerWidget {
  const TodoMateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    ref.listen(authStateProvider, (previous, next) {
      final uid = next.value?.uid;
      if (uid != null && previous?.value?.uid != uid) {
        FirestoreService(uid).backfillTodoCategoryPrivacy();
      }
    });
    ref.listen(profileDocProvider, (previous, next) {
      final saved = next.value?['themeMode'] as String?;
      final resolved = saved == 'dark'
          ? ThemeMode.dark
          : saved == 'light'
          ? ThemeMode.light
          : null;
      if (resolved != null && resolved != ref.read(themeModeProvider)) {
        ref.read(themeModeProvider.notifier).state = resolved;
      }
    });
    return MaterialApp(
      title: 'TODO on',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (user) => user == null
          ? const LoginScreen()
          : const UpdateChecker(child: HomeScreen()),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('오류: $e'))),
    );
  }
}
