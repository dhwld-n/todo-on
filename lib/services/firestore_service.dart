import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category.dart';
import '../models/diary_entry.dart';
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

  Future<void> deleteCategory(String categoryId) async {
    final batch = _db.batch();
    batch.delete(_categories.doc(categoryId));
    final affected = await _todos
        .where('categoryId', isEqualTo: categoryId)
        .get();
    for (final doc in affected.docs) {
      batch.update(doc.reference, {'categoryId': null});
    }
    await batch.commit();
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
    required List<String> destinationOrderedIds,
  }) async {
    final batch = _db.batch();
    for (var i = 0; i < destinationOrderedIds.length; i++) {
      final id = destinationOrderedIds[i];
      final data = <String, dynamic>{'order': i};
      if (id == todoId) data['categoryId'] = categoryId;
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

  Stream<List<String>> watchFollowing() {
    return _following.snapshots().map(
      (snap) => snap.docs.map((d) => d.id).toList(),
    );
  }

  Future<void> followUser(String targetUid) async {
    final batch = _db.batch();
    batch.set(_following.doc(targetUid), {
      'addedAt': Timestamp.fromDate(DateTime.now()),
    });
    batch.set(
      _db.collection('users').doc(targetUid).collection('followers').doc(uid),
      {'addedAt': Timestamp.fromDate(DateTime.now())},
    );
    await batch.commit();
  }

  Future<void> unfollowUser(String targetUid) async {
    final batch = _db.batch();
    batch.delete(_following.doc(targetUid));
    batch.delete(
      _db.collection('users').doc(targetUid).collection('followers').doc(uid),
    );
    await batch.commit();
  }

  Stream<Map<String, dynamic>?> watchFriendProfile(String friendUid) {
    return _db
        .collection('users')
        .doc(friendUid)
        .snapshots()
        .map((doc) => doc.data());
  }

  Stream<List<TodoItem>> watchFriendTodos(String friendUid) {
    return _db
        .collection('users')
        .doc(friendUid)
        .collection('todos')
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map(TodoItem.fromFirestore).toList());
  }

  Stream<List<TodoCategory>> watchFriendCategories(String friendUid) {
    return _db
        .collection('users')
        .doc(friendUid)
        .collection('categories')
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map(TodoCategory.fromFirestore).toList());
  }
}
