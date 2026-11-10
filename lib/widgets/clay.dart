import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// How a [Clay] surface sits: puffed up off the page, or pressed into it.
enum ClayDepth { raised, inset }

/// A soft, rounded "clay" surface: an outer drop shadow plus inner light
/// (top-left) and shade (bottom-right), so it reads as a puffy 3D blob.
/// Painted by [_ClayPainter] under the child.
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

  /// Tints the drop shadow (e.g. a todo card in its category's color).
  final Color? shadowColor;

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
    this.shadowColor,
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
    // tint, so the page stays airy rather than grey. In the dark the
    // colored parts glow instead (an even halo, no offset) and the rest
    // drop a plain black shadow.
    final tinted = color != null && !inset;
    final glow = shadowColor ?? (tinted ? fill : null);
    final List<BoxShadow> outer;
    if (inset) {
      outer = const [];
    } else if (dark && glow != null) {
      final strong = shadowColor == null;
      outer = [
        BoxShadow(
          color: glow.withValues(alpha: strong ? 0.6 : 0.42),
          blurRadius: strong ? 26 : 22,
        ),
        BoxShadow(
          color: glow.withValues(alpha: strong ? 0.5 : 0.55),
          blurRadius: strong ? 6 : 3,
        ),
      ];
    } else if (dark) {
      outer = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.7),
          blurRadius: small ? 14 : 30,
          offset: small ? const Offset(0, 6) : const Offset(0, 14),
        ),
      ];
    } else {
      outer = [
        BoxShadow(
          color: (glow ?? kClayBlue).withValues(
            alpha: shadowColor != null ? 0.38 : (tinted ? 0.36 : 0.16),
          ),
          blurRadius: small ? 16 : 34,
          offset: small ? const Offset(5, 8) : const Offset(12, 16),
        ),
      ];
    }
    final s = small ? 0.6 : 1.0;
    final light = inset
        ? (dark ? Colors.white.withValues(alpha: 0.05) : Colors.white)
        : (tinted
              ? Colors.white.withValues(alpha: 0.38)
              : (dark ? Colors.white.withValues(alpha: 0.06) : Colors.white));
    final shade = inset
        ? (dark
              ? Colors.black.withValues(alpha: 0.65)
              : kClayBlue.withValues(alpha: 0.16))
        : (tinted
              ? Colors.black.withValues(alpha: 0.22)
              : (dark
                    ? Colors.black.withValues(alpha: 0.4)
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
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _ClayPainter(
          fill: fill,
          outer: outer,
          inner: inner,
          radius: shape == BoxShape.circle ? null : radius,
          pixelRatio: MediaQuery.devicePixelRatioOf(context),
        ),
        // Its own layer: a ripple or a blinking child repaints only itself.
        child: RepaintBoundary(
          child: padding == null
              ? child
              : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}

class _Inner {
  final Color color;
  final Offset offset;
  final double blur;

  const _Inner(this.color, this.offset, this.blur);

  @override
  bool operator ==(Object other) =>
      other is _Inner &&
      other.color == color &&
      other.offset == offset &&
      other.blur == blur;

  @override
  int get hashCode => Object.hash(color, offset, blur);
}

/// Paints a clay surface: its drop shadow, fill and inner shading.
///
/// Every one of those is a blur, and Android's renderer (Impeller) keeps no
/// raster cache: it re-ran all of them on every frame, ~40 surfaces' worth,
/// which took ~560ms a frame on the emulator. So each look is blurred once
/// into a small image (a "skin": the four corners around a flat middle) and
/// from then on drawn as a nine-patch stretched to the surface's size.
class _ClayPainter extends CustomPainter {
  final Color fill;
  final List<BoxShadow> outer;
  final List<_Inner> inner;

  /// Corner radius; null for a circle.
  final double? radius;
  final double pixelRatio;

  const _ClayPainter({
    required this.fill,
    required this.outer,
    required this.inner,
    required this.radius,
    required this.pixelRatio,
  });

  // A few dozen looks at most (colors x sizes of corner); category tints
  // are the only open-ended part, hence the cap.
  static final _skins = <Object, _Skin>{};
  static const _maxSkins = 96;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final half = size.shortestSide / 2;
    // Halves of a pixel, so pills a hair apart in height share a skin.
    final r = (math.min(radius ?? half, half) * 2).round() / 2;
    // A corner patch has to hold the curve, the inner shading's reach, and
    // enough of a run for the drop shadow to come up to full strength.
    var corner = r;
    for (final s in inner) {
      corner = math.max(corner, s.offset.distance + s.blur);
    }
    var margin = 0.0;
    for (final s in outer) {
      corner = math.max(corner, s.blurRadius * 1.2);
      margin = math.max(margin, s.offset.distance + s.blurRadius * 1.6);
    }
    corner = math.min(corner.ceilToDouble(), (half * 2).floor() / 2);
    margin = margin.ceilToDouble();

    final key = Object.hash(
      fill,
      Object.hashAll(outer),
      Object.hashAll(inner),
      r,
      corner,
      pixelRatio,
    );
    final skin = _skins[key] ??= _makeSkin(r, corner, margin);

    canvas.save();
    // The skin is in physical pixels; a nine-patch's corners draw 1:1.
    canvas.scale(1 / pixelRatio);
    canvas.drawImageNine(
      skin.image,
      skin.center,
      Rect.fromLTRB(
        -margin * pixelRatio,
        -margin * pixelRatio,
        (size.width + margin) * pixelRatio,
        (size.height + margin) * pixelRatio,
      ),
      Paint()..filterQuality = FilterQuality.low,
    );
    canvas.restore();
  }

  _Skin _makeSkin(double r, double corner, double margin) {
    if (_skins.length >= _maxSkins) {
      for (final s in _skins.values) {
        s.image.dispose();
      }
      _skins.clear();
    }
    // Two corners and three flat pixels between them; the middle one is
    // what stretches, so filtering never reaches into a corner.
    final side = corner * 2 + 3;
    final rect = Rect.fromLTWH(margin, margin, side, side);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    for (final s in outer) {
      canvas.drawRRect(rrect.shift(s.offset), s.toPaint());
    }
    canvas.drawRRect(rrect, Paint()..color = fill);
    // Inner shadows: clipped to the shape, a blurred ring around it, shifted.
    canvas.clipRRect(rrect);
    final shape = Path()..addRRect(rrect);
    for (final s in inner) {
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
    final pixels = ((side + margin * 2) * pixelRatio).ceil();
    final picture = recorder.endRecording();
    final image = picture.toImageSync(pixels, pixels);
    picture.dispose();
    final mid = (margin + corner + 1) * pixelRatio;
    return _Skin(image, Rect.fromLTWH(mid, mid, pixelRatio, pixelRatio));
  }

  @override
  bool shouldRepaint(_ClayPainter old) =>
      old.fill != fill ||
      old.radius != radius ||
      old.pixelRatio != pixelRatio ||
      !listEquals(old.outer, outer) ||
      !listEquals(old.inner, inner);
}

class _Skin {
  final ui.Image image;

  /// The pixel of [image] that stretches, in its own pixels.
  final Rect center;

  const _Skin(this.image, this.center);
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
