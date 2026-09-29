import 'package:flutter/material.dart';

/// Hides the text caret while the focused field is composing (IME).
///
/// On Windows the Korean IME makes Flutter's engine put the caret at the
/// *start* of the syllable still being composed (it trusts GCS_CURSORPOS),
/// so it sits in the middle of what's typed. Moving the selection from Dart
/// mid-composition isn't an option: the engine then mis-records the
/// composing range and Korean input breaks. So the caret is just hidden
/// until the syllable is done, when it's back at the end on its own.
class ImeCaretGuard extends StatefulWidget {
  final Widget child;

  const ImeCaretGuard({super.key, required this.child});

  @override
  State<ImeCaretGuard> createState() => _ImeCaretGuardState();
}

class _ImeCaretGuardState extends State<ImeCaretGuard> {
  final _composing = ValueNotifier(false);
  TextEditingController? _watched;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChange);
    _watched?.removeListener(_update);
    _composing.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final controller = FocusManager.instance.primaryFocus?.context
        ?.findAncestorStateOfType<EditableTextState>()
        ?.widget
        .controller;
    if (controller == _watched) return;
    _watched?.removeListener(_update);
    _watched = controller?..addListener(_update);
    _update();
  }

  void _update() =>
      _composing.value = !(_watched?.value.composing.isCollapsed ?? true);

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: _composing,
    // Always the same wrapper (null = inherit), so toggling never remounts
    // the app below - that would drop the very composition in progress.
    builder: (context, composing, child) => DefaultSelectionStyle.merge(
      cursorColor: composing ? Colors.transparent : null,
      child: child!,
    ),
    child: widget.child,
  );
}
