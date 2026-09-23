import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Keep this in sync with pubspec.yaml's `version:` (the part before `+`).
const String kAppVersion = '1.6.16';

const String _kReleasesApiUrl =
    'https://api.github.com/repos/dhwld-n/todo-on/releases/latest';
const String kReleasesPageUrl =
    'https://github.com/dhwld-n/todo-on/releases/latest';

class UpdateInfo {
  final String latestVersion;
  final String? notes;
  final String? installerUrl;

  const UpdateInfo({
    required this.latestVersion,
    this.notes,
    this.installerUrl,
  });
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
      final assets = (data['assets'] as List?) ?? const [];
      String? installerUrl;
      for (final asset in assets) {
        final name = asset['name'] as String?;
        if (name != null && name.toLowerCase().endsWith('.exe')) {
          installerUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
      return UpdateInfo(
        latestVersion: latest,
        notes: data['body'] as String?,
        installerUrl: installerUrl,
      );
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Downloads the Windows installer to a temp file, reporting progress via
/// [onProgress] (received bytes, total bytes or null if unknown).
Future<String> downloadInstaller(
  String url, {
  void Function(int received, int? total)? onProgress,
}) async {
  final client = http.Client();
  try {
    final request = http.Request('GET', Uri.parse(url));
    final response = await client.send(request);
    if (response.statusCode != 200) {
      throw Exception('다운로드 실패 (HTTP ${response.statusCode})');
    }
    final total = response.contentLength;
    final destPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}TODOon-Setup-latest.exe';
    final file = File(destPath);
    final sink = file.openWrite();
    var received = 0;
    await response.stream
        .map((chunk) {
          received += chunk.length;
          onProgress?.call(received, total);
          return chunk;
        })
        .pipe(sink);
    return destPath;
  } finally {
    client.close();
  }
}

/// Launches the downloaded installer silently (it force-closes this app if
/// needed and relaunches it once done) and exits this process immediately.
Future<void> installAndExit(String installerPath) async {
  await Process.start(installerPath, [
    '/VERYSILENT',
    '/SUPPRESSMSGBOXES',
    '/NORESTART',
    '/CLOSEAPPLICATIONS',
    '/FORCECLOSEAPPLICATIONS',
    '/NORESTARTAPPLICATIONS',
  ], mode: ProcessStartMode.detached);
  exit(0);
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
