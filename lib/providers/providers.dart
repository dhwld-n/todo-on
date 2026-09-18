import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/diary_entry.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/todo_item.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/update_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final userProfileProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).userChanges;
});

final profileDocProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  if (service == null) return const Stream.empty();
  return service.watchProfile();
});

final firestoreServiceProvider = Provider<FirestoreService?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return FirestoreService(user.uid);
});

final categoriesProvider = StreamProvider<List<TodoCategory>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  if (service == null) return const Stream.empty();
  return service.watchCategories();
});

final todosProvider = StreamProvider<List<TodoItem>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  if (service == null) return const Stream.empty();
  return service.watchTodos();
});

DateTime _todayAtMidnight() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

final selectedDateProvider = StateProvider<DateTime?>(
  (ref) => _todayAtMidnight(),
);

final focusedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

enum ContentMode { todo, diary, friends, habits }

final contentModeProvider = StateProvider<ContentMode>(
  (ref) => ContentMode.todo,
);

/// Whether the calendar is shown inline on narrow (phone-width) layouts,
/// where there's no room to keep it permanently side-by-side like on wide
/// screens. Defaults to shown, so the calendar isn't hidden behind a tap.
final mobileCalendarExpandedProvider = StateProvider<bool>((ref) => true);

String dateKeyFor(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

final diaryEntryProvider = StreamProvider.autoDispose
    .family<DiaryEntry?, String>((ref, dateKey) {
      final service = ref.watch(firestoreServiceProvider);
      if (service == null) return const Stream.empty();
      return service.watchDiaryEntry(dateKey);
    });

final habitsProvider = StreamProvider<List<Habit>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  if (service == null) return const Stream.empty();
  return service.watchHabits();
});

final habitLogsProvider = StreamProvider<List<HabitLog>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  if (service == null) return const Stream.empty();
  return service.watchHabitLogs();
});

final updateInfoProvider = FutureProvider<UpdateInfo?>((ref) {
  return checkForUpdate();
});

/// Whether the user has already acknowledged the pending update (dismisses
/// the tab-rail badge, but the item itself stays until they actually update).
final updateSeenProvider = StateProvider<bool>((ref) => false);

final followingProvider = StreamProvider<List<String>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  if (service == null) return const Stream.empty();
  return service.watchFollowing();
});

final friendProfileProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, friendUid) {
      final service = ref.watch(firestoreServiceProvider);
      if (service == null) return const Stream.empty();
      return service.watchFriendProfile(friendUid);
    });

final friendTodosProvider = StreamProvider.autoDispose
    .family<List<TodoItem>, String>((ref, friendUid) {
      final service = ref.watch(firestoreServiceProvider);
      if (service == null) return const Stream.empty();
      return service.watchFriendTodos(friendUid);
    });

final friendCategoriesProvider = StreamProvider.autoDispose
    .family<List<TodoCategory>, String>((ref, friendUid) {
      final service = ref.watch(firestoreServiceProvider);
      if (service == null) return const Stream.empty();
      return service.watchFriendCategories(friendUid);
    });
