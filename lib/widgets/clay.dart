import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// How a [Clay] surface sits: puffed up off the page, or pressed into it.
enum ClayDepth { raised, inset }

/// A soft, rounded "clay" surface: an outer drop shadow plus inner light
/// (top-left) and shade (bottom-right), so it reads as a puffy 3D blob.
/// Flutter's BoxShadow can't draw inner shadows, so those are painted by
/// [_InnerShadowPainter] under the child.
class Clay extends StatelessWidget {
  final Widget? child;
  final double radius;

  /// The fill; the theme's surface when null.
  final Color? color;
  final ClayDepth depth;

  /// Smaller shadows for buttons, chips and rows.
  final bool small;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final BoxShape shape;

  const Clay({
    super.key,
    this.child,
    this.radius = 32,
    this.color,
    this.depth = ClayDepth.raised,
    this.small = false,
    this.padding,
    this.width,
    this.height,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final inset = depth == ClayDepth.inset;
    final fill =
        color ??
        (inset
            ? (dark ? kDarkInputFill : const Color(0xFFEEF3FF))
            : Theme.of(context).colorScheme.surface);
    // A colored blob throws a shadow of its own color; a white one a blue
    // tint, so the page stays airy rather than grey.
    final tinted = color != null && !inset;
    final outer = inset
        ? const <BoxShadow>[]
        : [
            BoxShadow(
              color: dark
                  ? Colors.black.withValues(alpha: 0.45)
                  : (tinted ? fill : kClayBlue).withValues(
                      alpha: tinted ? 0.36 : 0.16,
                    ),
              blurRadius: small ? 16 : 34,
              offset: small ? const Offset(5, 8) : const Offset(12, 16),
            ),
          ];
    final s = small ? 0.6 : 1.0;
    final light = inset
        ? (dark ? Colors.white.withValues(alpha: 0.05) : Colors.white)
        : (tinted
              ? Colors.white.withValues(alpha: 0.38)
              : (dark ? Colors.white.withValues(alpha: 0.07) : Colors.white));
    final shade = inset
        ? (dark
              ? Colors.black.withValues(alpha: 0.45)
              : kClayBlue.withValues(alpha: 0.16))
        : (tinted
              ? Colors.black.withValues(alpha: 0.22)
              : (dark
                    ? Colors.black.withValues(alpha: 0.35)
                    : kClayBlue.withValues(alpha: 0.10)));
    // Raised: light falls on the top-left, shade sits bottom-right. Inset:
    // the rim's shadow falls inside the top-left edge instead.
    final inner = inset
        ? [
            _Inner(shade, Offset(6 * s, 6 * s), 12 * s),
            _Inner(light, Offset(-6 * s, -6 * s), 12 * s),
          ]
        : [
            _Inner(light, Offset(7 * s, 7 * s), 14 * s),
            _Inner(shade, Offset(-7 * s, -8 * s), 16 * s),
          ];
    final borderRadius = shape == BoxShape.circle
        ? null
        : BorderRadius.circular(radius);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        shape: shape,
        borderRadius: borderRadius,
        boxShadow: outer,
      ),
      child: CustomPaint(
        painter: _InnerShadowPainter(
          inner,
          shape == BoxShape.circle ? null : radius,
        ),
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
  }
}

class _Inner {
  final Color color;
  final Offset offset;
  final double blur;

  const _Inner(this.color, this.offset, this.blur);
}

/// Inner shadows: clipped to the shape, a blurred ring around it, shifted.
class _InnerShadowPainter extends CustomPainter {
  final List<_Inner> shadows;

  /// Corner radius; null for a circle.
  final double? radius;

  const _InnerShadowPainter(this.shadows, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = radius == null
        ? (Path()..addOval(rect))
        : (Path()..addRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(radius!)),
          ));
    canvas.save();
    canvas.clipPath(shape);
    for (final s in shadows) {
      final ring = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect.inflate(s.blur * 3 + s.offset.distance))
        ..addPath(shape, Offset.zero);
      canvas.drawPath(
        ring.shift(s.offset),
        Paint()
          ..color = s.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur / 2),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InnerShadowPainter old) =>
      old.radius != radius || old.shadows != shadows;
}

/// A round clay button holding one icon (app bar actions, chevrons, +).
class ClayIconButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;

  const ClayIconButton({
    super.key,
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.size = 42,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final button = Clay(
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
