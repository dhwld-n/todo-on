import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Lets the user drag/zoom [source] under a round frame and returns the
/// framed square, or null if they cancel.
Future<img.Image?> showPhotoCropDialog(
  BuildContext context,
  img.Image source,
) => showDialog<img.Image>(
  context: context,
  builder: (_) => _PhotoCropDialog(source: source),
);

class _PhotoCropDialog extends StatefulWidget {
  final img.Image source;

  const _PhotoCropDialog({required this.source});

  @override
  State<_PhotoCropDialog> createState() => _PhotoCropDialogState();
}

class _PhotoCropDialogState extends State<_PhotoCropDialog> {
  // Phone photos carry their rotation in EXIF; bake it in so the preview and
  // the crop agree. A profile picture ends up 256px, so 1024 is plenty.
  late final img.Image _image = () {
    final upright = img.bakeOrientation(widget.source);
    return math.max(upright.width, upright.height) > 1024
        ? img.copyResize(
            upright,
            width: upright.width >= upright.height ? 1024 : null,
            height: upright.height > upright.width ? 1024 : null,
          )
        : upright;
  }();
  late final Uint8List _preview = img.encodeJpg(_image, quality: 90);
  final _controller = TransformationController();
  double? _side;
  late Size _childSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_side != null) return;
    // Fit inside the dialog on a phone (insets + padding), 280 elsewhere.
    final side = math.min(280.0, MediaQuery.sizeOf(context).width - 128);
    _side = side;
    // The image scaled to just cover the frame, centered.
    final cover = side / math.min(_image.width, _image.height);
    _childSize = Size(_image.width * cover, _image.height * cover);
    _controller.value = Matrix4.translationValues(
      -(_childSize.width - side) / 2,
      -(_childSize.height - side) / 2,
      0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  img.Image _crop() {
    final side = _side!;
    final topLeft = _controller.toScene(Offset.zero);
    final bottomRight = _controller.toScene(Offset(side, side));
    final toPx = _image.width / _childSize.width;
    final maxSize = math.min(_image.width, _image.height);
    final size = ((bottomRight.dx - topLeft.dx) * toPx).round().clamp(
      1,
      maxSize,
    );
    return img.copyCrop(
      _image,
      x: (topLeft.dx * toPx).round().clamp(0, _image.width - size),
      y: (topLeft.dy * toPx).round().clamp(0, _image.height - size),
      width: size,
      height: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final side = _side!;
    return AlertDialog(
      title: const Text('사진 영역 선택'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: side,
            child: ClipRect(
              child: Stack(
                children: [
                  InteractiveViewer(
                    transformationController: _controller,
                    constrained: false,
                    boundaryMargin: EdgeInsets.zero,
                    minScale: 1,
                    maxScale: 8,
                    child: Image.memory(
                      _preview,
                      width: _childSize.width,
                      height: _childSize.height,
                      fit: BoxFit.fill,
                    ),
                  ),
                  IgnorePointer(
                    child: CustomPaint(
                      size: Size.square(side),
                      painter: _RoundFramePainter(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '끌어서 위치를 옮기고, 두 손가락이나 마우스 휠로 확대해요',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_crop()),
          child: const Text('완료'),
        ),
      ],
    );
  }
}

/// Dims everything outside the circle the avatar will show.
class _RoundFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect)
        ..addOval(rect),
      Paint()..color = Colors.black54,
    );
    canvas.drawOval(
      rect.deflate(1),
      Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_RoundFramePainter oldDelegate) => false;
}
