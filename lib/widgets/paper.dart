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

  /// The theme with its text fields written on a line instead of boxed,
  /// for a form that should read like a page of the diary.
  static ThemeData ruledFields(BuildContext context) {
    final theme = Theme.of(context);
    final line = BorderSide(color: Diary.edge(context), width: 1.5);
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
      listTileTheme: theme.listTileTheme.copyWith(
        iconColor: theme.colorScheme.onSurface,
      ),
    );
  }

  /// A filled icon button in ink (send).
  static ButtonStyle inkIconButton(BuildContext context) =>
      IconButton.styleFrom(
        backgroundColor: Diary.edge(context),
        foregroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
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

/// A round picture with an inked edge: a photo, or an initial or icon in
/// ink on paper.
class InkAvatar extends StatelessWidget {
  final double radius;
  final ImageProvider? image;
  final String? initial;
  final IconData? icon;

  const InkAvatar({
    super.key,
    required this.radius,
    this.image,
    this.initial,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Diary.edge(context), width: 1.5),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        backgroundImage: image,
        child: image != null
            ? null
            : icon != null
            ? Icon(icon, size: radius)
            : Text(initial ?? '?'),
      ),
    );
  }
}

/// A list row as an index card: paper with an inked edge.
ShapeBorder inkCardShape(BuildContext context) => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(12),
  side: BorderSide(color: Diary.edge(context), width: 1.5),
);
