import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

class Dday {
  final String id;
  final String label;
  final DateTime date;

  const Dday({required this.id, required this.label, required this.date});

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'date': Timestamp.fromDate(date),
  };

  /// The profile's D-days, earliest date first. Profiles from before
  /// multiple D-days kept a single one in ddayLabel/ddayDate: it's read as
  /// part of the list, and the next save moves it into `ddays`.
  static List<Dday> listFrom(Map<String, dynamic>? profile) {
    final list = [
      for (final raw in (profile?['ddays'] as List?) ?? const [])
        if (raw is Map && raw['date'] is Timestamp)
          Dday(
            id: raw['id'] as String? ?? '',
            label: raw['label'] as String? ?? '',
            date: (raw['date'] as Timestamp).toDate(),
          ),
    ];
    final legacyLabel = profile?['ddayLabel'] as String?;
    final legacyDate = (profile?['ddayDate'] as Timestamp?)?.toDate();
    if (legacyLabel != null && legacyDate != null) {
      list.add(Dday(id: 'legacy', label: legacyLabel, date: legacyDate));
    }
    return list..sort((a, b) => a.date.compareTo(b.date));
  }
}
