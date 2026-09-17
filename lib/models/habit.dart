import 'package:cloud_firestore/cloud_firestore.dart';

class Habit {
  final String id;
  final String name;
  final String? subtitle;
  final String emoji;
  final int colorValue;
  final int order;
  final DateTime createdAt;

  const Habit({
    required this.id,
    required this.name,
    this.subtitle,
    required this.emoji,
    required this.colorValue,
    required this.order,
    required this.createdAt,
  });

  factory Habit.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final createdTimestamp = data['createdAt'] as Timestamp?;
    return Habit(
      id: doc.id,
      name: data['name'] as String,
      subtitle: data['subtitle'] as String?,
      emoji: data['emoji'] as String? ?? '⭐',
      colorValue: data['colorValue'] as int? ?? 0xFF42A5F5,
      order: data['order'] as int? ?? 0,
      createdAt: createdTimestamp?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'subtitle': subtitle,
      'emoji': emoji,
      'colorValue': colorValue,
      'order': order,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Habit copyWith({
    String? name,
    String? subtitle,
    bool clearSubtitle = false,
    String? emoji,
    int? colorValue,
    int? order,
  }) {
    return Habit(
      id: id,
      name: name ?? this.name,
      subtitle: clearSubtitle ? null : (subtitle ?? this.subtitle),
      emoji: emoji ?? this.emoji,
      colorValue: colorValue ?? this.colorValue,
      order: order ?? this.order,
      createdAt: createdAt,
    );
  }
}
