import 'dart:typed_data';

import 'package:doc_tools/doc_tools.dart';
import 'package:test/test.dart';

/// A 480 × 640 grey frame: a dark desk with a bright page from (80, 60) to
/// (400, 580), rows padded to [stride].
Uint8List frame({int stride = 480}) {
  final f = Uint8List(stride * 640);
  for (var y = 0; y < 640; y++) {
    for (var x = 0; x < 480; x++) {
      final page = x >= 80 && x < 400 && y >= 60 && y < 580;
      f[y * stride + x] = page ? 235 : 40 + (x * 7 + y * 3) % 25;
    }
  }
  return f;
}

void main() {
  test(
    'finds the page as fractions of the frame, off the UI isolate',
    () async {
      final page = await detectFramePage(frame(), 480, 640);
      expect(page, isNotNull);
      final tl = page!.corners.first, br = page.corners[2];
      expect(tl.x, closeTo(80 / 480, 0.03));
      expect(tl.y, closeTo(60 / 640, 0.03));
      expect(br.x, closeTo(400 / 480, 0.03));
      expect(br.y, closeTo(580 / 640, 0.03));
    },
  );

  test('padded rows (the camera\'s row stride)', () async {
    final page = await detectFramePage(
      frame(stride: 512),
      480,
      640,
      rowStride: 512,
    );
    expect(page, isNotNull);
  });

  test('no page: null', () async {
    expect(await detectFramePage(Uint8List(480 * 640), 480, 640), isNull);
  });
}
