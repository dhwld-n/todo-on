import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/providers.dart';

class DiaryPane extends ConsumerStatefulWidget {
  final DateTime date;

  const DiaryPane({super.key, required this.date});

  @override
  ConsumerState<DiaryPane> createState() => _DiaryPaneState();
}

class _DiaryPaneState extends ConsumerState<DiaryPane> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String? _loadedKey;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSave(String dateKey) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      ref
          .read(firestoreServiceProvider)
          ?.saveDiaryEntry(dateKey, _controller.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateKey = dateKeyFor(widget.date);
    final entryAsync = ref.watch(diaryEntryProvider(dateKey));

    return entryAsync.when(
      data: (entry) {
        if (_loadedKey != dateKey) {
          _loadedKey = dateKey;
          _controller.text = entry?.content ?? '';
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
        }
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('yyyy년 M월 d일 EEEE', 'ko_KR').format(widget.date),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: 'GriunFromsol',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    fontFamily: 'GriunFromsol',
                    height: 1.5,
                  ),
                  decoration: const InputDecoration(
                    hintText: '오늘 하루는 어땠나요?',
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => _scheduleSave(dateKey),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
    );
  }
}
