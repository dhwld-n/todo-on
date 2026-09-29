import 'package:flutter/foundation.dart';

/// Computers: the chat box is multi-line, Shift+Enter adds a line and a
/// bare Enter sends. Phones keep their keyboard's send key.
bool get chatEnterSendsOnDesktop => switch (defaultTargetPlatform) {
  TargetPlatform.windows ||
  TargetPlatform.macOS ||
  TargetPlatform.linux => true,
  _ => false,
};

/// The text to send if [after] is just [before] plus one newline typed at
/// the caret by a bare Enter, else null (Shift+Enter, pasted lines, ...).
///
/// Enter is caught here, after the engine has inserted its newline, rather
/// than as a key press: by then the IME has committed the Korean syllable
/// being typed, so the last letter is never cut off.
String? bareEnterSubmission(
  String before,
  String after,
  int caret, {
  required bool shiftPressed,
}) {
  if (shiftPressed ||
      caret < 1 ||
      caret > after.length ||
      after.length != before.length + 1 ||
      after[caret - 1] != '\n' ||
      after.replaceRange(caret - 1, caret, '') != before) {
    return null;
  }
  return before;
}
