import 'package:cloud_firestore/cloud_firestore.dart';

/// Marks that [uid] wrote content up through character index [upTo]
/// (exclusive) of the entry's cumulative `content`. Segments are ordered
/// and consecutive - each one picks up where the previous left off.
class DiarySegment {
  final String uid;
  final int upTo;

  const DiarySegment({required this.uid, required this.upTo});

  factory DiarySegment.fromMap(Map<String, dynamic> map) {
    return DiarySegment(
      uid: map['uid'] as String? ?? '',
      upTo: map['upTo'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {'uid': uid, 'upTo': upTo};

  /// Appends or extends [segments] with [uid] having written up to
  /// [contentLength]. Consecutive writes by the same author extend their
  /// existing segment instead of piling up a new one per keystroke.
  static List<DiarySegment> update(
    List<DiarySegment> segments,
    String uid,
    int contentLength,
  ) {
    if (segments.isNotEmpty && segments.last.uid == uid) {
      return [
        ...segments.sublist(0, segments.length - 1),
        DiarySegment(uid: uid, upTo: contentLength),
      ];
    }
    return [...segments, DiarySegment(uid: uid, upTo: contentLength)];
  }
}

class SharedDiaryEntry {
  final String dateKey;
  final String content;
  final DateTime updatedAt;
  final String updatedBy;
  final List<DiarySegment> segments;

  /// Per uid, the [updatedAt] of the last edit that person has seen. Stored
  /// as the edit's own timestamp (not "now") so the two devices' clocks
  /// never have to agree.
  final Map<String, DateTime> seenAt;

  const SharedDiaryEntry({
    required this.dateKey,
    required this.content,
    required this.updatedAt,
    required this.updatedBy,
    this.segments = const [],
    this.seenAt = const {},
  });

  /// The other person edited this after [uid] last looked at it.
  bool hasUnseenEditFor(String uid) {
    if (updatedBy.isEmpty || updatedBy == uid) return false;
    final seen = seenAt[uid];
    return seen == null || seen.isBefore(updatedAt);
  }

  factory SharedDiaryEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final updatedTimestamp = data['updatedAt'] as Timestamp?;
    final rawSegments = data['segments'] as List<dynamic>? ?? const [];
    final rawSeenAt = data['seenAt'] as Map<String, dynamic>? ?? const {};
    return SharedDiaryEntry(
      dateKey: doc.id,
      content: data['content'] as String? ?? '',
      updatedAt: updatedTimestamp?.toDate() ?? DateTime.now(),
      updatedBy: data['updatedBy'] as String? ?? '',
      segments: rawSegments
          .map((s) => DiarySegment.fromMap(s as Map<String, dynamic>))
          .toList(),
      seenAt: {
        for (final e in rawSeenAt.entries)
          if (e.value is Timestamp) e.key: (e.value as Timestamp).toDate(),
      },
    );
  }
}
