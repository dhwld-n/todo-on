import 'package:cloud_firestore/cloud_firestore.dart';

/// A single completed day for a habit. Doc id is `${habitId}_$dateKey`.
class HabitLog {
  final String habitId;
  final String dateKey;

  const HabitLog({required this.habitId, required this.dateKey});

  factory HabitLog.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return HabitLog(
      habitId: data['habitId'] as String,
      dateKey: data['dateKey'] as String,
    );
  }
}
