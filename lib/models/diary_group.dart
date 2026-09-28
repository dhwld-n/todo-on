import 'package:cloud_firestore/cloud_firestore.dart';

class DiaryGroup {
  final String id;
  final String? name;
  final List<String> members;
  final String createdBy;

  const DiaryGroup({
    required this.id,
    this.name,
    required this.members,
    required this.createdBy,
  });

  factory DiaryGroup.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return DiaryGroup(
      id: doc.id,
      name: data['name'] as String?,
      members: List<String>.from(data['members'] as List? ?? const []),
      createdBy: data['createdBy'] as String? ?? '',
    );
  }
}
