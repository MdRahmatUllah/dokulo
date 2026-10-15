import 'dart:io';
import 'dart:typed_data';

import 'package:doc_core/doc_core.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:test/test.dart';

const mmPerPoint = 25.4 / 72;

/// A card-shaped JPEG (ID-1 proportions at 300 dpi).
Uint8List card(int shade) => Uint8List.fromList(
  img.encodeJpg(
    img.Image(width: 1011, height: 638)
      ..clear(img.ColorRgb8(shade, shade, 255)),
  ),
);

void main() {
  setUpAll(pdfrxInitialize);

  test('the layout: true size, front above back, centred', () {
    final (:front, :back) = idCardLayout();
    for (final b in [front, back]) {
      expect((b.right - b.left) * mmPerPoint, closeTo(85.6, 0.01));
      expect((b.top - b.bottom) * mmPerPoint, closeTo(54, 0.01));
      expect(
        b.left + b.right,
        closeTo(a4Width, 0.01),
        reason: 'centred across',
      );
    }
    expect(front.bottom, greaterThan(back.top), reason: 'front above back');
    expect(
      front.top + back.bottom,
      closeTo(a4Height, 0.01),
      reason: 'centred down',
    );
  });

  test(
    'the PDF: one A4 page; both images measure 85.6 × 54 mm ±1 mm',
    () async {
      final dir = await Directory.systemTemp.createTemp('dk_id_');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/id.pdf';
      await File(path).writeAsBytes(await idCardPdf(card(200), card(120)));
      final info = await PdfEngine.inspect(path);
      expect(info.pageCount, 1);
      expect(info.pages.first.width, closeTo(a4Width, 0.5));
      final images = await PdfEngine.images(path, 0);
      expect(images, hasLength(2));
      for (final im in images) {
        expect((im.box.right - im.box.left) * mmPerPoint, closeTo(85.6, 1));
        expect((im.box.top - im.box.bottom) * mmPerPoint, closeTo(54, 1));
      }
    },
  );
}
