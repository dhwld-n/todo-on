import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_on/providers/providers.dart';

// hasUnreadChatProvider and hasUnseenSharedDiaryProvider each have their own
// tests; this only checks the OR composition that drives the OS taskbar
// badge (windows_taskbar itself isn't unit-testable - it's a native overlay
// on the app's own taskbar icon).
void main() {
  bool badge({required bool chat, required bool diary}) {
    final container = ProviderContainer(
      overrides: [
        hasUnreadChatProvider.overrideWithValue(chat),
        hasUnseenSharedDiaryProvider.overrideWithValue(diary),
      ],
    );
    addTearDown(container.dispose);
    return container.read(hasAnyBadgeProvider);
  }

  test('no badge when both are quiet', () {
    expect(badge(chat: false, diary: false), isFalse);
  });

  test('badge when only chat is unread', () {
    expect(badge(chat: true, diary: false), isTrue);
  });

  test('badge when only the diary has an unseen edit', () {
    expect(badge(chat: false, diary: true), isTrue);
  });

  test('badge when both are unread', () {
    expect(badge(chat: true, diary: true), isTrue);
  });
}
