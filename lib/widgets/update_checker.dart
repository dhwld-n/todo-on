import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';

class UpdateChecker extends StatefulWidget {
  final Widget child;

  const UpdateChecker({super.key, required this.child});

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checked) {
      _checked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  Future<void> _check() async {
    final info = await checkForUpdate();
    if (info == null || !mounted) return;
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
              launchUrl(
                Uri.parse(kReleasesPageUrl),
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text('다운로드 페이지 열기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
