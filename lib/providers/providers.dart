import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/chat_message.dart';
import '../models/diary_entry.dart';
import '../models/diary_group.dart';
import '../models/group_chat.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/shared_diary_entry.dart';
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

/// True when running as the Android app, so the UI can switch to a
/// phone-shaped layout (bottom nav) instead of the desktop side rail.
final isAndroidPlatformProvider = Provider<bool>(
  (ref) => !kIsWeb && Platform.isAndroid,
);

enum ContentMode { todo, diary, friends, habits, chat }

final contentModeProvider = StateProvider<ContentMode>(
  (ref) => ContentMode.todo,
);

/// Whether the calendar is shown inline on narrow (phone-width) layouts,
/// where there's no room to keep it permanently side-by-side like on wide
/// screens. Defaults to shown, so the calendar isn't hidden behind a tap.
final mobileCalendarExpandedProvider = StateProvider<bool>((ref) => true);

/// The todo currently being dragged to a new spot, so its original row can
/// fade out while it's in flight.
final draggingTodoIdProvider = StateProvider<String?>((ref) => null);

String dateKeyFor(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

final diaryEntryProvider = StreamProvider.autoDispose
    .family<DiaryEntry?, String>((ref, dateKey) {
      final service = ref.watch(firestoreServiceProvider);
      if (service == null) return const Stream.empty();
      return service.watchDiaryEntry(dateKey);
    });

enum DiaryTab { private, shared }

final diaryTabProvider = StateProvider<DiaryTab>((ref) => DiaryTab.private);

/// Which friend's exchange diary is currently open. Null until the user
/// picks one (defaults to the first friend once the friend list loads).
final sharedDiaryFriendProvider = StateProvider<String?>((ref) => null);

final sharedDiaryEntryProvider = StreamProvider.autoDispose
    .family<SharedDiaryEntry?, ({String otherUid, String dateKey})>((
      ref,
      params,
    ) {
      final service = ref.watch(firestoreServiceProvider);
      if (service == null) return const Stream.empty();
      return service.watchSharedDiaryEntry(params.otherUid, params.dateKey);
    });

/// Dates a friend edited in our shared diary that I haven't seen yet.
final unseenSharedDiaryDatesProvider = StreamProvider.autoDispose
    .family<List<String>, String>((ref, friendUid) {
      final service = ref.watch(firestoreServiceProvider);
      if (service == null) return const Stream.empty();
      return service.watchUnseenSharedDiaryDates(friendUid);
    });

/// Diary groups (multi-person exchange diaries) I'm a member of.
final myDiaryGroupsProvider = StreamProvider<List<DiaryGroup>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  if (service == null) return const Stream.empty();
  return service.watchMyDiaryGroups();
});

/// Which diary group is currently open, if any - takes priority over
/// [sharedDiaryFriendProvider] while set. Null falls back to friend mode.
final sharedDiaryGroupProvider = StateProvider<String?>((ref) => null);

final diaryGroupEntryProvider = StreamProvider.autoDispose
    .family<SharedDiaryEntry?, ({String groupId, String dateKey})>((
      ref,
      params,
    ) {
      final service = ref.watch(firestoreServiceProvider);
      if (service == null) return const Stream.empty();
      return service.watchDiaryGroupEntry(params.groupId, params.dateKey);
    });

/// Dates a diary group entry was edited by someone else that I haven't
/// seen yet.
final unseenDiaryGroupDatesProvider = StreamProvider.autoDispose
    .family<List<String>, String>((ref, groupId) {
      final service = ref.watch(firestoreServiceProvider);
      if (service == null) return const Stream.empty();
      return service.watchUnseenDiaryGroupDates(groupId);
    });

final myDiaryDatesProvider = StreamProvider<Set<String>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  if (service == null) return const Stream.empty();
  return service.watchDiaryDates();
});

final sharedDiaryDatesProvider = StreamProvider.autoDispose
    .family<Set<String>, String>((ref, friendUid) {
      final service = ref.watch(firestoreServiceProvider);
      if (service == null) return const Stream.empty();
      return service.watchSharedDiaryDates(friendUid);
    });

final diaryGroupDatesProvider = StreamProvider.autoDispose
    .family<Set<String>, String>((ref, groupId) {
      final service = ref.watch(firestoreServiceProvider);
      if (service == null) return const Stream.empty();
      return service.watchDiaryGroupDates(groupId);
    });

/// Date keys with text in any exchange diary (1:1 or group), for the
/// calendar's exchange-diary marker; [myDiaryDatesProvider] is the private one.
final exchangeDiaryDatesProvider = Provider<Set<String>>((ref) {
  final uids = ref.watch(followingProvider).value ?? const [];
  final groups = ref.watch(myDiaryGroupsProvider).value ?? const [];
  return {
    for (final uid in uids) ...?ref.watch(sharedDiaryDatesProvider(uid)).value,
    for (final group in groups)
      ...?ref.watch(diaryGroupDatesProvider(group.id)).value,
  };
});

/// Any friend or diary group has a shared-diary edit I haven't seen, for
/// the 일기 tab dot.
final hasUnseenSharedDiaryProvider = Provider<bool>((ref) {
  final uids = ref.watch(followingProvider).value ?? const [];
  final groups = ref.watch(myDiaryGroupsProvider).value ?? const [];
  // Watch every friend/group (no early return) so none of their streams drop.
  final unseen = [
    for (final uid in uids)
      ref.watch(unseenSharedDiaryDatesProvider(uid)).value?.isNotEmpty ?? false,
    for (final group in groups)
      ref.watch(unseenDiaryGroupDatesProvider(group.id)).value?.isNotEmpty ??
          false,
  ];
  return unseen.contains(true);
});

final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, friendUid) {
      final service = ref.watch(firestoreServiceProvider);
      if (service == null) return const Stream.empty();
      return service.watchChatMessages(friendUid);
    });

final chatLastReadProvider = StreamProvider.autoDispose
    .family<DateTime?, String>((ref, friendUid) {
      final service = ref.watch(firestoreServiceProvider);
      if (service == null) return const Stream.empty();
      return service.watchChatLastRead(friendUid);
    });

final myGroupChatsProvider = StreamProvider<List<GroupChat>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  if (service == null) return const Stream.empty();
  return service.watchMyGroupChats();
});

final groupMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, groupId) {
      final service = ref.watch(firestoreServiceProvider);
      if (service == null) return const Stream.empty();
      return service.watchGroupMessages(groupId);
    });

final groupLastReadProvider = StreamProvider.autoDispose
    .family<Map<String, DateTime>, String>((ref, groupId) {
      final service = ref.watch(firestoreServiceProvider);
      if (service == null) return const Stream.empty();
      return service.watchGroupLastRead(groupId);
    });

final chatFriendLastReadProvider = StreamProvider.autoDispose
    .family<DateTime?, String>((ref, friendUid) {
      final service = ref.watch(firestoreServiceProvider);
      if (service == null) return const Stream.empty();
      return service.watchFriendLastRead(friendUid);
    });

/// True if any friend has sent a message since our last read of that chat -
/// same unread rule as each row in [ChatListPane], just OR'd across friends
/// so the 채팅 tab icon can show a badge without opening the list.
final hasUnreadChatProvider = Provider<bool>((ref) {
  final uids = ref.watch(followingProvider).value ?? const [];
  final myUid = ref.watch(authStateProvider).value?.uid;
  for (final uid in uids) {
    final messages = ref.watch(chatMessagesProvider(uid)).value ?? const [];
    final lastRead = ref.watch(chatLastReadProvider(uid)).value;
    final hasUnread = messages.any(
      (m) =>
          m.senderUid != myUid &&
          (lastRead == null || m.createdAt.isAfter(lastRead)),
    );
    if (hasUnread) return true;
  }
  final groups = ref.watch(myGroupChatsProvider).value ?? const [];
  for (final group in groups) {
    final messages =
        ref.watch(groupMessagesProvider(group.id)).value ?? const [];
    final lastRead = ref.watch(groupLastReadProvider(group.id)).value?[myUid];
    final hasUnread = messages.any(
      (m) =>
          m.senderUid != myUid &&
          (lastRead == null || m.createdAt.isAfter(lastRead)),
    );
    if (hasUnread) return true;
  }
  return false;
});

/// Drives the OS-level app icon badge (Windows taskbar overlay for now):
/// true while there's an unread chat message or an unseen shared-diary edit.
final hasAnyBadgeProvider = Provider<bool>(
  (ref) =>
      ref.watch(hasUnreadChatProvider) ||
      ref.watch(hasUnseenSharedDiaryProvider),
);

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
