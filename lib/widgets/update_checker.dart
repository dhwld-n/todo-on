import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/providers.dart';
import '../services/update_service.dart';

Future<void> openDownloadPage() {
  return launchUrl(
    Uri.parse(kReleasesPageUrl),
    mode: LaunchMode.externalApplication,
  );
}

void showUpdateDialog(BuildContext context, UpdateInfo info) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('새 버전이 있어요'),
      content: Text(
        'v$kAppVersion → v${info.latestVersion}\n\n'
        '${info.notes?.trim().isNotEmpty == true ? info.notes!.trim() : '다운로드 페이지에서 새 버전을 받아보세요.'}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('나중에'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            openDownloadPage();
          },
          child: const Text('다운로드 페이지 열기'),
        ),
      ],
    ),
  );
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
