import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category.dart';
import '../models/diary_entry.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/shared_diary_entry.dart';
import '../models/todo_item.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String uid;

  FirestoreService(this.uid);

  CollectionReference<Map<String, dynamic>> get _categories =>
      _db.collection('users').doc(uid).collection('categories');

  CollectionReference<Map<String, dynamic>> get _todos =>
      _db.collection('users').doc(uid).collection('todos');

  CollectionReference<Map<String, dynamic>> get _diary =>
      _db.collection('users').doc(uid).collection('diary');

  CollectionReference<Map<String, dynamic>> get _habits =>
      _db.collection('users').doc(uid).collection('habits');

  CollectionReference<Map<String, dynamic>> get _habitLogs =>
      _db.collection('users').doc(uid).collection('habit_logs');

  DocumentReference<Map<String, dynamic>> get _profile =>
      _db.collection('users').doc(uid);

  Stream<List<TodoCategory>> watchCategories() {
    return _categories
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map(TodoCategory.fromFirestore).toList());
  }

  Stream<List<TodoItem>> watchTodos() {
    return _todos
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map(TodoItem.fromFirestore).toList());
  }

  Future<void> addCategory(TodoCategory category) {
    return _categories.doc(category.id).set(category.toFirestore());
  }

  Future<void> updateCategory(TodoCategory category) {
    return _categories.doc(category.id).update(category.toFirestore());
  }

  /// Updates the category's privacy and cascades the denormalized
  /// `categoryIsPrivate` flag onto every todo currently under it.
  Future<void> setCategoryPrivate(String categoryId, bool isPrivate) async {
    final batch = _db.batch();
    batch.update(_categories.doc(categoryId), {'isPrivate': isPrivate});
    final affected = await _todos
        .where('categoryId', isEqualTo: categoryId)
        .get();
    for (final doc in affected.docs) {
      batch.update(doc.reference, {'categoryIsPrivate': isPrivate});
    }
    await batch.commit();
  }

  /// Persists a new drag-and-drop order for all categories.
  Future<void> reorderCategories(List<String> orderedIds) async {
    final batch = _db.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(_categories.doc(orderedIds[i]), {'order': i});
    }
    await batch.commit();
  }

  Future<void> deleteCategory(String categoryId) async {
    final batch = _db.batch();
    batch.delete(_categories.doc(categoryId));
    final affected = await _todos
        .where('categoryId', isEqualTo: categoryId)
        .get();
    for (final doc in affected.docs) {
      batch.update(doc.reference, {
        'categoryId': null,
        'categoryIsPrivate': false,
      });
    }
    await batch.commit();
  }

  /// One-time self-heal for todos written before `categoryIsPrivate` existed
  /// (or left stale by a category-privacy change made outside the app).
  Future<void> backfillTodoCategoryPrivacy() async {
    final categoriesSnap = await _categories.get();
    final privacyById = {
      for (final doc in categoriesSnap.docs)
        doc.id: doc.data()['isPrivate'] as bool? ?? false,
    };
    final todosSnap = await _todos.get();
    final batch = _db.batch();
    var hasChanges = false;
    for (final doc in todosSnap.docs) {
      final data = doc.data();
      final categoryId = data['categoryId'] as String?;
      final expected = categoryId != null
          ? (privacyById[categoryId] ?? false)
          : false;
      final current = data['categoryIsPrivate'] as bool?;
      if (current != expected) {
        batch.update(doc.reference, {'categoryIsPrivate': expected});
        hasChanges = true;
      }
    }
    if (hasChanges) await batch.commit();
  }

  Future<void> addTodo(TodoItem todo) {
    return _todos.doc(todo.id).set(todo.toFirestore());
  }

  Future<void> updateTodo(TodoItem todo) {
    return _todos.doc(todo.id).update(todo.toFirestore());
  }

  Future<void> deleteTodo(String todoId) {
    return _todos.doc(todoId).delete();
  }

  Future<void> setDone(String todoId, bool isDone) {
    return _todos.doc(todoId).update({'isDone': isDone});
  }

  /// Reassigns [todoId] to [categoryId] and rewrites the `order` field of
  /// every id in [destinationOrderedIds] (which must include [todoId] at its
  /// new position) to match that list's order.
  Future<void> moveTodo({
    required String todoId,
    required String? categoryId,
    required bool categoryIsPrivate,
    required List<String> destinationOrderedIds,
  }) async {
    final batch = _db.batch();
    for (var i = 0; i < destinationOrderedIds.length; i++) {
      final id = destinationOrderedIds[i];
      final data = <String, dynamic>{'order': i};
      if (id == todoId) {
        data['categoryId'] = categoryId;
        data['categoryIsPrivate'] = categoryIsPrivate;
      }
      batch.update(_todos.doc(id), data);
    }
    await batch.commit();
  }

  Stream<DiaryEntry?> watchDiaryEntry(String dateKey) {
    return _diary
        .doc(dateKey)
        .snapshots()
        .map((doc) => doc.exists ? DiaryEntry.fromFirestore(doc) : null);
  }

  Future<void> saveDiaryEntry(String dateKey, String content) {
    return _diary.doc(dateKey).set({
      'content': content,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
  }

  /// The two participants' uids, sorted so both sides derive the same id
  /// for their shared diary regardless of who started it.
  String sharedDiaryId(String otherUid) {
    final ids = [uid, otherUid]..sort();
    return ids.join('_');
  }

  CollectionReference<Map<String, dynamic>> _sharedDiaryEntries(
    String otherUid,
  ) => _db
      .collection('sharedDiaries')
      .doc(sharedDiaryId(otherUid))
      .collection('entries');

  Stream<SharedDiaryEntry?> watchSharedDiaryEntry(
    String otherUid,
    String dateKey,
  ) {
    return _sharedDiaryEntries(otherUid)
        .doc(dateKey)
        .snapshots()
        .map((doc) => doc.exists ? SharedDiaryEntry.fromFirestore(doc) : null);
  }

  Future<void> saveSharedDiaryEntry(
    String otherUid,
    String dateKey,
    String content,
  ) {
    return _sharedDiaryEntries(otherUid).doc(dateKey).set({
      'content': content,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'updatedBy': uid,
    }, SetOptions(merge: true));
  }

  Stream<List<Habit>> watchHabits() {
    return _habits
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map(Habit.fromFirestore).toList());
  }

  Future<void> addHabit(Habit habit) {
    return _habits.doc(habit.id).set(habit.toFirestore());
  }

  Future<void> updateHabit(Habit habit) {
    return _habits.doc(habit.id).update(habit.toFirestore());
  }

  Future<void> deleteHabit(String habitId) {
    return _habits.doc(habitId).delete();
  }

  Stream<List<HabitLog>> watchHabitLogs() {
    return _habitLogs.snapshots().map(
      (snap) => snap.docs.map(HabitLog.fromFirestore).toList(),
    );
  }

  Future<void> setHabitLog({
    required String habitId,
    required String dateKey,
    required bool completed,
  }) {
    final docId = '${habitId}_$dateKey';
    if (completed) {
      return _habitLogs.doc(docId).set({'habitId': habitId, 'dateKey': dateKey});
    }
    return _habitLogs.doc(docId).delete();
  }

  Stream<Map<String, dynamic>?> watchProfile() {
    return _profile.snapshots().map((doc) => doc.data());
  }

  Future<void> saveProfile({
    String? nickname,
    String? bio,
    String? photoBase64,
  }) {
    final data = <String, dynamic>{};
    if (nickname != null) data['nickname'] = nickname;
    if (bio != null) data['bio'] = bio;
    if (photoBase64 != null) data['photoBase64'] = photoBase64;
    return _profile.set(data, SetOptions(merge: true));
  }

  Future<void> saveThemeMode(String themeMode) {
    return _profile.set({'themeMode': themeMode}, SetOptions(merge: true));
  }

  CollectionReference<Map<String, dynamic>> get _following =>
      _db.collection('users').doc(uid).collection('following');

  CollectionReference<Map<String, dynamic>> get _followers =>
      _db.collection('users').doc(uid).collection('followers');

  Stream<List<String>> watchFollowing() {
    return _following.snapshots().map(
      (snap) => snap.docs.map((d) => d.id).toList(),
    );
  }

  /// Friending is mutual: adding someone by their code immediately makes
  /// both sides follow each other, so they both show up in "내 친구"
  /// without the other person having to add the code back.
  Future<void> followUser(String targetUid) async {
    final now = Timestamp.fromDate(DateTime.now());
    final targetDoc = _db.collection('users').doc(targetUid);
    final batch = _db.batch();
    batch.set(_following.doc(targetUid), {'addedAt': now});
    batch.set(_followers.doc(targetUid), {'addedAt': now});
    batch.set(targetDoc.collection('following').doc(uid), {'addedAt': now});
    batch.set(targetDoc.collection('followers').doc(uid), {'addedAt': now});
    await batch.commit();
  }

  /// Relationships created before mutual following existed are still
  /// one-directional in Firestore (that side never got the missing docs
  /// added retroactively), which is why some friends can't read your
  /// profile/nickname even though the add "worked". Re-runs the same
  /// 4-way write for every friend already in my following or followers,
  /// filling in whichever side is missing.
  Future<void> backfillMutualFollows() async {
    final followingSnap = await _following.get();
    final followersSnap = await _followers.get();
    final friendIds = {
      ...followingSnap.docs.map((d) => d.id),
      ...followersSnap.docs.map((d) => d.id),
    };
    if (friendIds.isEmpty) return;
    final now = Timestamp.fromDate(DateTime.now());
    final batch = _db.batch();
    for (final friendId in friendIds) {
      final targetDoc = _db.collection('users').doc(friendId);
      batch.set(_following.doc(friendId), {
        'addedAt': now,
      }, SetOptions(merge: true));
      batch.set(_followers.doc(friendId), {
        'addedAt': now,
      }, SetOptions(merge: true));
      batch.set(targetDoc.collection('following').doc(uid), {
        'addedAt': now,
      }, SetOptions(merge: true));
      batch.set(targetDoc.collection('followers').doc(uid), {
        'addedAt': now,
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> unfollowUser(String targetUid) async {
    final targetDoc = _db.collection('users').doc(targetUid);
    final batch = _db.batch();
    batch.delete(_following.doc(targetUid));
    batch.delete(_followers.doc(targetUid));
    batch.delete(targetDoc.collection('following').doc(uid));
    batch.delete(targetDoc.collection('followers').doc(uid));
    await batch.commit();
  }

  Stream<Map<String, dynamic>?> watchFriendProfile(String friendUid) {
    return _db
        .collection('users')
        .doc(friendUid)
        .snapshots()
        .map((doc) => doc.data());
  }

  /// A Firestore list query fails entirely if even one document it could
  /// match would be denied by the security rules. `categoryIsPrivate` is
  /// denormalized onto each todo precisely so this query can filter on the
  /// todo itself instead of needing (unreadable) access to private
  /// category documents to know which ones to exclude.
  Stream<List<TodoItem>> watchFriendTodos(String friendUid) {
    return _db
        .collection('users')
        .doc(friendUid)
        .collection('todos')
        .where('categoryIsPrivate', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.map(TodoItem.fromFirestore).toList());
  }

  Stream<List<TodoCategory>> watchFriendCategories(String friendUid) {
    return _db
        .collection('users')
        .doc(friendUid)
        .collection('categories')
        .where('isPrivate', isEqualTo: false)
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map(TodoCategory.fromFirestore).toList());
  }
}
