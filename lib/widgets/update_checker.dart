import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/providers.dart';
import '../services/update_service.dart';

bool get _isAndroid => !kIsWeb && Platform.isAndroid;

/// On Android this starts the apk download straight away - the release's
/// own versioned file when known ([UpdateInfo.apkUrl]); elsewhere it opens
/// the GitHub releases page.
Future<void> openDownloadPage({String? apkUrl}) {
  return launchUrl(
    Uri.parse(_isAndroid ? (apkUrl ?? kLatestApkUrl) : kReleasesPageUrl),
    mode: LaunchMode.externalApplication,
  );
}

void showUpdateDialog(BuildContext context, UpdateInfo info) {
  showDialog<void>(
    context: context,
    builder: (context) => _UpdateDialog(info: info),
  );
}

enum _UpdateStage { prompt, downloading, installing, error }

class _UpdateDialog extends StatefulWidget {
  final UpdateInfo info;

  const _UpdateDialog({required this.info});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  _UpdateStage _stage = _UpdateStage.prompt;
  double? _progress;
  String? _error;
  String? _apkPath;

  bool get _canAutoUpdate => _isAndroid
      ? widget.info.apkUrl != null
      : !kIsWeb && Platform.isWindows && widget.info.installerUrl != null;

  void _onProgress(int received, int? total) {
    if (!mounted) return;
    setState(() {
      _progress = total != null && total > 0 ? received / total : null;
    });
  }

  Future<void> _startUpdate() async {
    setState(() {
      _stage = _UpdateStage.downloading;
      _progress = 0;
    });
    try {
      if (_isAndroid) {
        final path = await downloadApk(
          widget.info.apkUrl!,
          onProgress: _onProgress,
        );
        _apkPath = path;
        await openApkInstaller(path);
        // Stay open: the first install detours through "allow this source"
        // settings, and Android then returns here instead of the installer.
        if (mounted) setState(() => _stage = _UpdateStage.installing);
        return;
      }
      final path = await downloadInstaller(
        widget.info.installerUrl!,
        onProgress: _onProgress,
      );
      if (!mounted) return;
      setState(() => _stage = _UpdateStage.installing);
      await installAndExit(path);
      // installAndExit exits the process on success; nothing to do after.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _UpdateStage.error;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _UpdateStage.downloading:
        return AlertDialog(
          title: const Text('다운로드 중이에요'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 12),
              Text(
                _progress != null
                    ? '${(_progress! * 100).toStringAsFixed(0)}%'
                    : '잠시만 기다려주세요...',
              ),
            ],
          ),
        );
      case _UpdateStage.installing when _isAndroid:
        return AlertDialog(
          title: const Text('설치 화면에서 업데이트를 눌러주세요'),
          content: const Text(
            '설치 화면이 안 보이거나, "출처를 알 수 없는 앱"을 허용하고 '
            '돌아왔다면 아래 버튼을 눌러주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
            FilledButton(
              onPressed: () => openApkInstaller(_apkPath!),
              child: const Text('설치 화면 다시 열기'),
            ),
          ],
        );
      case _UpdateStage.installing:
        return const AlertDialog(
          title: Text('설치하고 있어요'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(),
              SizedBox(height: 12),
              Text('곧 앱이 자동으로 다시 시작돼요.'),
            ],
          ),
        );
      case _UpdateStage.error:
        return AlertDialog(
          title: const Text('업데이트에 실패했어요'),
          content: Text('$_error\n\n다운로드 페이지에서 직접 받아주세요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                openDownloadPage(apkUrl: widget.info.apkUrl);
              },
              child: const Text('다운로드 페이지 열기'),
            ),
          ],
        );
      case _UpdateStage.prompt:
        return AlertDialog(
          title: const Text('새 버전이 있어요'),
          content: Text(
            'v$kAppVersion → v${widget.info.latestVersion}\n\n'
            '${widget.info.notes?.trim().isNotEmpty == true ? widget.info.notes!.trim() : '다운로드 페이지에서 새 버전을 받아보세요.'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('나중에'),
            ),
            // Android's error dialog still offers the browser route; three
            // buttons don't fit a phone-width row.
            if (_canAutoUpdate && !_isAndroid)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  openDownloadPage(apkUrl: widget.info.apkUrl);
                },
                child: const Text('다운로드 페이지에서 받기'),
              ),
            FilledButton(
              onPressed: _canAutoUpdate
                  ? _startUpdate
                  : () {
                      Navigator.of(context).pop();
                      openDownloadPage(apkUrl: widget.info.apkUrl);
                    },
              child: Text(
                _canAutoUpdate
                    ? '지금 업데이트'
                    : (_isAndroid ? 'apk 받기' : '다운로드 페이지 열기'),
              ),
            ),
          ],
        );
    }
  }
}

class UpdateChecker extends ConsumerStatefulWidget {
  final Widget child;

  const UpdateChecker({super.key, required this.child});

  @override
  ConsumerState<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends ConsumerState<UpdateChecker> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(updateInfoProvider, (previous, next) {
      final info = next.value;
      if (info == null || _shown) return;
      _shown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showUpdateDialog(context, info);
      });
    });
    return widget.child;
  }
}
