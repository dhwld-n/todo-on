import 'dart:convert';

import 'package:http/http.dart' as http;

/// Keep this in sync with pubspec.yaml's `version:` (the part before `+`).
const String kAppVersion = '1.2.0';

const String _kReleasesApiUrl =
    'https://api.github.com/repos/dhwld-n/todo-on/releases/latest';
const String kReleasesPageUrl =
    'https://github.com/dhwld-n/todo-on/releases/latest';

class UpdateInfo {
  final String latestVersion;
  final String? notes;

  const UpdateInfo({required this.latestVersion, this.notes});
}

/// Returns update info if GitHub's latest release is newer than
/// [kAppVersion], or null if up to date / the check failed.
Future<UpdateInfo?> checkForUpdate() async {
  try {
    final response = await http
        .get(
          Uri.parse(_kReleasesApiUrl),
          headers: {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] as String?) ?? '';
    final latest = tag.startsWith('v') ? tag.substring(1) : tag;
    if (latest.isEmpty) return null;

    if (_isNewer(latest, kAppVersion)) {
      return UpdateInfo(latestVersion: latest, notes: data['body'] as String?);
    }
    return null;
  } catch (_) {
    return null;
  }
}

bool _isNewer(String remote, String local) {
  final r = _parseVersion(remote);
  final l = _parseVersion(local);
  for (var i = 0; i < 3; i++) {
    if (r[i] != l[i]) return r[i] > l[i];
  }
  return false;
}

List<int> _parseVersion(String version) {
  final parts = version.split('.');
  return List.generate(3, (i) {
    if (i >= parts.length) return 0;
    return int.tryParse(parts[i]) ?? 0;
  });
}
