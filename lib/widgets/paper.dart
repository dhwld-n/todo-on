import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The diary look's inks, which change with light and dark.
abstract final class Diary {
  static bool _dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// The pen line around paper and buttons; also the fill of a selected tab.
  static Color edge(BuildContext context) =>
      _dark(context) ? kEdgeDark : kEdgeLight;

  /// The hard shadow paper casts, a little down and to the right.
  static Color lift(BuildContext context) =>
      _dark(context) ? const Color(0x61000000) : const Color(0x21000000);

  /// Ruled lines: the calendar's boxes, the dashes under each todo.
  static Color rule(BuildContext context) =>
      _dark(context) ? const Color(0x2EFFFFFF) : const Color(0x29000000);

  static Color muted(BuildContext context) =>
      _dark(context) ? const Color(0xFFB4B1AA) : const Color(0xFF666666);

  /// [color] laid on paper like a highlighter pen.
  static Color highlight(
    BuildContext context,
    Color color, [
    double strength = 1,
  ]) => color.withValues(alpha: (_dark(context) ? 0.5 : 0.42) * strength);

  /// The pen under the day's date: yellow on light, a lime that keeps the
  /// white date readable on dark.
  static Color marker(BuildContext context) => _dark(context)
      ? const Color(0xFF8FD14F).withValues(alpha: 0.38)
      : kAccentYellow.withValues(alpha: 0.76);

  /// The theme with its form controls drawn in ink: fields written on a
  /// line, buttons and chips with an inked edge, the chosen one filled in
  /// ink. For sheets and forms that should match the diary pages.
  static ThemeData controls(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final paper = theme.colorScheme.surface;
    final edge = Diary.edge(context);
    final line = BorderSide(color: edge, width: 1.5);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    WidgetStateProperty<Color> pick(Color on, Color off) =>
        WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? on : off,
        );
    return theme.copyWith(
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: UnderlineInputBorder(borderSide: line),
        enabledBorder: UnderlineInputBorder(borderSide: line),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        labelStyle: TextStyle(color: Diary.muted(context)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: ink),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: line,
          shape: shape,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: edge,
          foregroundColor: paper,
          shape: shape,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: pick(edge, Colors.transparent),
          foregroundColor: pick(paper, ink),
          side: WidgetStatePropertyAll(line),
          shape: WidgetStatePropertyAll(shape),
        ),
      ),
      chipTheme: theme.chipTheme.copyWith(
        backgroundColor: paper,
        selectedColor: edge,
        secondarySelectedColor: edge,
        checkmarkColor: paper,
        labelStyle: theme.chipTheme.labelStyle?.copyWith(color: ink),
        secondaryLabelStyle: theme.chipTheme.secondaryLabelStyle?.copyWith(
          color: paper,
        ),
        side: line,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: pick(paper, edge),
        trackColor: pick(edge, paper),
        trackOutlineColor: WidgetStatePropertyAll(edge),
      ),
      listTileTheme: theme.listTileTheme.copyWith(iconColor: ink),
    );
  }
}

/// A sheet of paper: flat, an inked edge, lifted a little off the page by a
/// hard shadow. No blur anywhere - Android's renderer redraws every blur on
/// every frame.
class Paper extends StatelessWidget {
  final Widget? child;
  final double radius;

  /// The fill; the theme's surface (paper) when null.
  final Color? color;

  /// A smaller lift, for buttons and tabs.
  final bool small;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final BoxShape shape;

  const Paper({
    super.key,
    this.child,
    this.radius = 14,
    this.color,
    this.small = false,
    this.padding,
    this.width,
    this.height,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surface,
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(radius),
        border: Border.all(color: Diary.edge(context), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Diary.lift(context),
            offset: small ? const Offset(2, 3) : const Offset(3, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A round paper button holding one icon (app bar actions, chevrons, +).
class PaperIconButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;

  const PaperIconButton({
    super.key,
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.size = 42,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final button = Paper(
      small: true,
      shape: BoxShape.circle,
      width: size,
      height: size,
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(child: Icon(icon, size: iconSize)),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// [child] run over with a highlighter: a band of [color] behind its lower
/// half.
class Highlighted extends StatelessWidget {
  final Widget child;
  final Color color;

  const Highlighted({super.key, required this.child, required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.55, 0.55],
          colors: [color.withValues(alpha: 0), color],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: child,
      ),
    );
  }
}

/// A dashed pen line across the width it's given.
class DashedRule extends StatelessWidget {
  final Color? color;

  const DashedRule({super.key, this.color});

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(double.infinity, 1.5),
    painter: _DashPainter(color ?? Diary.rule(context)),
  );
}

class _DashPainter extends CustomPainter {
  final Color color;

  const _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, y), Offset(x + 5, y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// Grid paper: the page the home screen sits on.
class GridPaper24 extends StatelessWidget {
  final Widget child;

  const GridPaper24({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return CustomPaint(
      painter: _GridPainter(
        theme.scaffoldBackgroundColor,
        dark ? const Color(0x12FFFFFF) : const Color(0x13000000),
      ),
      child: child,
    );
  }
}

class _GridPainter extends CustomPainter {
  static const _step = 24.0;
  final Color background;
  final Color color;

  const _GridPainter(this.background, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.5; x < size.width; x += _step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.5; y < size.height; y += _step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.color != color || old.background != background;
}
