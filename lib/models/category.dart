import 'package:cloud_firestore/cloud_firestore.dart';

class TodoCategory {
  final String id;
  final String name;
  final int colorValue;
  final int order;
  final bool isPrivate;

  const TodoCategory({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.order,
    this.isPrivate = false,
  });

  factory TodoCategory.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return TodoCategory(
      id: doc.id,
      name: data['name'] as String,
      colorValue: data['colorValue'] as int,
      order: data['order'] as int? ?? 0,
      isPrivate: data['isPrivate'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'colorValue': colorValue,
      'order': order,
      'isPrivate': isPrivate,
    };
  }

  TodoCategory copyWith({
    String? name,
    int? colorValue,
    int? order,
    bool? isPrivate,
  }) {
    return TodoCategory(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      order: order ?? this.order,
      isPrivate: isPrivate ?? this.isPrivate,
    );
  }
}
