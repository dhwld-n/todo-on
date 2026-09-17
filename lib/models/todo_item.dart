import 'package:cloud_firestore/cloud_firestore.dart';

class TodoItem {
  final String id;
  final String title;
  final String? categoryId;
  final bool isDone;
  final DateTime? dueDate;
  final DateTime createdAt;
  final int order;
  final String? note;
  // Denormalized from the category's own isPrivate flag at write time, so
  // friend-visible queries can filter on the todo directly instead of
  // needing read access to the (possibly private) category document.
  final bool categoryIsPrivate;

  const TodoItem({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.isDone,
    required this.dueDate,
    required this.createdAt,
    required this.order,
    this.note,
    this.categoryIsPrivate = false,
  });

  factory TodoItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final dueTimestamp = data['dueDate'] as Timestamp?;
    final createdTimestamp = data['createdAt'] as Timestamp?;
    return TodoItem(
      id: doc.id,
      title: data['title'] as String,
      categoryId: data['categoryId'] as String?,
      isDone: data['isDone'] as bool? ?? false,
      dueDate: dueTimestamp?.toDate(),
      createdAt: createdTimestamp?.toDate() ?? DateTime.now(),
      order: data['order'] as int? ?? 0,
      note: data['note'] as String?,
      categoryIsPrivate: data['categoryIsPrivate'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'categoryId': categoryId,
      'isDone': isDone,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'order': order,
      'note': note,
      'categoryIsPrivate': categoryIsPrivate,
    };
  }

  TodoItem copyWith({
    String? title,
    String? categoryId,
    bool clearCategory = false,
    bool? isDone,
    DateTime? dueDate,
    bool clearDueDate = false,
    int? order,
    String? note,
    bool clearNote = false,
    bool? categoryIsPrivate,
  }) {
    return TodoItem(
      id: id,
      title: title ?? this.title,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      isDone: isDone ?? this.isDone,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      createdAt: createdAt,
      order: order ?? this.order,
      note: clearNote ? null : (note ?? this.note),
      categoryIsPrivate: categoryIsPrivate ?? this.categoryIsPrivate,
    );
  }
}
