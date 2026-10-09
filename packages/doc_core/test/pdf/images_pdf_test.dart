import 'dart:io';
import 'dart:typed_data';

import 'package:doc_core/doc_core.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:test/test.dart';

({Uint8List jpeg, int width, int height}) jpeg(int w, int h) => (
  jpeg: Uint8List.fromList(
    img.encodeJpg(
      img.Image(width: w, height: h)..clear(img.ColorRgb8(240, 238, 230)),
    ),
  ),
  width: w,
  height: h,
);

void main() {
  setUpAll(pdfrxInitialize);

  Future<PdfInfo> write(Uint8List pdf) async {
    final dir = await Directory.systemTemp.createTemp('dk_img_');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/scan.pdf';
    await File(path).writeAsBytes(pdf);
    return PdfEngine.inspect(path);
  }

  test('fit: each page in its image\'s proportions, A4 wide', () async {
    final info = await write(await imagesPdf([jpeg(600, 800), jpeg(800, 400)]));
    expect(info.pageCount, 2);
    expect(info.pages[0].width, closeTo(a4Width, 0.5));
    expect(info.pages[0].height, closeTo(a4Width * 4 / 3, 0.5));
    expect(info.pages[1].height, closeTo(a4Width / 2, 0.5));
  });

  test('A4 and Letter: the page turns with the image', () async {
    final a4 = await write(
      await imagesPdf([jpeg(600, 800), jpeg(800, 600)], page: ImagesPdfPage.a4),
    );
    expect(a4.pages[0].width, closeTo(a4Width, 0.5));
    expect(a4.pages[1].width, closeTo(a4Height, 0.5));
    final letter = await write(
      await imagesPdf([jpeg(600, 800)], page: ImagesPdfPage.letter),
    );
    expect(letter.pages[0].width, closeTo(letterWidth, 0.5));
  });
}
