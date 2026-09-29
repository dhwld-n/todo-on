import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/theme_prefs.dart';

const kMinTextScale = 0.8;
const kMaxTextScale = 1.3;

void showSettingsDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _SettingsDialog());

class _SettingsDialog extends ConsumerWidget {
  const _SettingsDialog();

  void _set(WidgetRef ref, double scale) {
    ref.read(textScaleProvider.notifier).state = scale;
    saveCachedTextScale(scale);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(textScaleProvider);
    final percent = '${(scale * 100).round()}%';
    return AlertDialog(
      title: const Text('설정'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '글자 크기',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(percent),
            ],
          ),
          Row(
            children: [
              const Text('가', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: scale,
                  min: kMinTextScale,
                  max: kMaxTextScale,
                  divisions: 10,
                  label: percent,
                  // Applies live, so the whole app behind the dialog shows
                  // the result while dragging.
                  onChanged: (v) => _set(ref, v),
                ),
              ),
              const Text('가', style: TextStyle(fontSize: 20)),
            ],
          ),
          Text(
            '이 기기에만 적용돼요.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).disabledColor,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: scale == 1.0 ? null : () => _set(ref, 1.0),
          child: const Text('기본 크기로'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}
