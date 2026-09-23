import 'package:cloud_firestore/cloud_firestore.dart';

class SharedDiaryEntry {
  final String dateKey;
  final String content;
  final DateTime updatedAt;
  final String updatedBy;

  const SharedDiaryEntry({
    required this.dateKey,
    required this.content,
    required this.updatedAt,
    required this.updatedBy,
  });

  factory SharedDiaryEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final updatedTimestamp = data['updatedAt'] as Timestamp?;
    return SharedDiaryEntry(
      dateKey: doc.id,
      content: data['content'] as String? ?? '',
      updatedAt: updatedTimestamp?.toDate() ?? DateTime.now(),
      updatedBy: data['updatedBy'] as String? ?? '',
    );
  }
}
