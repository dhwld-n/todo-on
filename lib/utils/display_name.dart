/// A friend/member's nickname, or a short id-based fallback before their
/// profile has loaded. Real Firebase uids are always long, but a uid
/// shorter than 8 chars (test data, or a not-yet-loaded empty string)
/// must not crash on the naive `substring(0, 8)`.
String displayNameFor(Map<String, dynamic>? profile, String uid) {
  final nickname = (profile?['nickname'] as String?)?.trim();
  if (nickname != null && nickname.isNotEmpty) return nickname;
  return uid.length >= 8 ? uid.substring(0, 8) : uid;
}
