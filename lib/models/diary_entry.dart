import 'package:cloud_firestore/cloud_firestore.dart';

class DiaryEntry {
  final String dateKey;
  final String content;
  final DateTime updatedAt;

  const DiaryEntry({
    required this.dateKey,
    required this.content,
    required this.updatedAt,
  });

  factory DiaryEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final updatedTimestamp = data['updatedAt'] as Timestamp?;
    return DiaryEntry(
      dateKey: doc.id,
      content: data['content'] as String? ?? '',
      updatedAt: updatedTimestamp?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'content': content, 'updatedAt': Timestamp.fromDate(updatedAt)};
  }
}
