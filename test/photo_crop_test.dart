import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:todo_on/widgets/photo_crop_dialog.dart';

/// 400x200: left half red, right half blue.
img.Image _halfRedHalfBlue() {
  final image = img.Image(width: 400, height: 200);
  for (final p in image) {
    p.setRgb(p.x < 200 ? 255 : 0, 0, p.x < 200 ? 0 : 255);
  }
  return image;
}

bool _isRed(img.Pixel p) => p.r > 200 && p.b < 50;
bool _isBlue(img.Pixel p) => p.b > 200 && p.r < 50;

Future<img.Image?> _crop(
  WidgetTester tester, {
  required double width,
  Offset drag = Offset.zero,
  double wheel = 0,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  img.Image? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              result = await showPhotoCropDialog(context, _halfRedHalfBlue()),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  if (drag != Offset.zero) {
    await tester.drag(find.byType(InteractiveViewer), drag);
    await tester.pumpAndSettle();
  }
  if (wheel != 0) {
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      pointer.hover(tester.getCenter(find.byType(InteractiveViewer))),
    );
    await tester.sendEventToBinding(pointer.scroll(Offset(0, wheel)));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('완료'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('starts on the centered square of a wide photo', (tester) async {
    final crop = (await _crop(tester, width: 800))!;
    expect(crop.width, crop.height);
    expect(crop.width, 200);
    // Centered: red on the left edge, blue on the right edge.
    expect(_isRed(crop.getPixel(5, 100)), isTrue);
    expect(_isBlue(crop.getPixel(crop.width - 5, 100)), isTrue);
  });

  testWidgets('dragging the photo picks which part becomes the picture', (
    tester,
  ) async {
    // Photo dragged right = frame over its left (red) half, on a phone.
    final left = (await _crop(tester, width: 360, drag: const Offset(400, 0)))!;
    expect(_isRed(left.getPixel(5, 100)), isTrue);
    expect(_isRed(left.getPixel(left.width - 5, 100)), isTrue);
  });

  testWidgets('and the other way gets the right (blue) half', (tester) async {
    final right = (await _crop(
      tester,
      width: 360,
      drag: const Offset(-400, 0),
    ))!;
    expect(_isBlue(right.getPixel(5, 100)), isTrue);
    expect(_isBlue(right.getPixel(right.width - 5, 100)), isTrue);
  });

  testWidgets('cancel keeps the old picture', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Object? result = 'untouched';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await showPhotoCropDialog(context, _halfRedHalfBlue()),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('the mouse wheel zooms in on desktop', (tester) async {
    final zoomed = (await _crop(tester, width: 800, wheel: -300))!;
    expect(zoomed.width, zoomed.height);
    expect(zoomed.width, lessThan(150));
  });
}
