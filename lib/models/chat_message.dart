import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderUid;
  final String text;
  final String? imageBase64;
  final DateTime createdAt;
  final bool edited;

  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.text,
    this.imageBase64,
    required this.createdAt,
    this.edited = false,
  });

  factory ChatMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final createdTimestamp = data['createdAt'] as Timestamp?;
    return ChatMessage(
      id: doc.id,
      senderUid: data['senderUid'] as String? ?? '',
      text: data['text'] as String? ?? '',
      imageBase64: data['imageBase64'] as String?,
      createdAt: createdTimestamp?.toDate() ?? DateTime.now(),
      edited: data['editedAt'] != null,
    );
  }
}
