import 'dart:io';
import 'dart:typed_data';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:qpdf_ffi/qpdf_ffi.dart';
import 'package:test/test.dart';

/// A [width] × [height] JPEG, with an EXIF [orientation] when given.
Uint8List jpeg(int width, int height, {int? orientation}) {
  final im = img.Image(width: width, height: height)
    ..clear(img.ColorRgb8(30, 90, 200));
  if (orientation != null) im.exif.imageIfd.orientation = orientation;
  return img.encodeJpg(im);
}

Uint8List png(int width, int height) => img.encodePng(
  img.Image(width: width, height: height)..clear(img.ColorRgb8(200, 60, 40)),
);

/// Whether [needle] appears in [hay] byte for byte.
bool contains(Uint8List hay, Uint8List needle) {
  outer:
  for (var i = 0; i <= hay.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

void main() {
  setUpAll(pdfrxInitialize);

  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('dk_i2p_'));
  tearDown(() => dir.delete(recursive: true));

  group('imagePageLayout', () {
    test('Fit image: the image\'s proportions, long side as A4\'s', () {
      final l = imagePageLayout(3000, 4000, ImagePageSize.fit);
      expect(l.pageHeight, closeTo(a4Height, 0.01));
      expect(l.pageWidth, closeTo(a4Height * 3 / 4, 0.01));
      // No margins: the image fills the page.
      expect(l.image.left, closeTo(0, 1e-6));
      expect(l.image.bottom, closeTo(0, 1e-6));
      expect(l.image.right, closeTo(l.pageWidth, 1e-6));
      expect(l.image.top, closeTo(l.pageHeight, 1e-6));
    });

    test('A4 and Letter turn to a landscape image', () {
      final a4 = imagePageLayout(4000, 3000, ImagePageSize.a4);
      expect((a4.pageWidth, a4.pageHeight), (a4Height, a4Width));
      final letter = imagePageLayout(1000, 2000, ImagePageSize.letter);
      expect(
        (letter.pageWidth, letter.pageHeight),
        (letterWidth, letterHeight),
      );
    });

    test('Small margins: fitted inside them, centred', () {
      final l = imagePageLayout(1000, 1000, ImagePageSize.a4, margins: true);
      final b = l.image;
      expect(b.right - b.left, closeTo(a4Width - 2 * smallMargin, 0.01));
      expect(b.left, closeTo(smallMargin, 0.01));
      expect(b.bottom + b.top, closeTo(a4Height, 0.01), reason: 'centred');
    });
  });

  test('a JPEG goes in unchanged, turned by its EXIF orientation', () async {
    // 400 × 300 pixels, "rotate 90° CW" (6): a portrait page.
    final photo = jpeg(400, 300, orientation: 6);
    final out = '${dir.path}/out.pdf';
    final w = ImagesPdfWriter(out, workDir: dir);
    await w.add(photo);
    expect(await w.close(IsolatePool(tempRoot: dir)), 1);
    final page = (await PdfEngine.inspect(out)).pages.single;
    expect(page.height, closeTo(a4Height, 0.5));
    expect(page.width, closeTo(a4Height * 300 / 400, 0.5));
    expect(contains(File(out).readAsBytesSync(), photo), isTrue);
  });

  test('PNG and JPEG pages in order; A4 with margins', () async {
    final out = '${dir.path}/out.pdf';
    final w = ImagesPdfWriter(
      out,
      workDir: dir,
      size: ImagePageSize.a4,
      margins: true,
    );
    await w.add(png(300, 200));
    await w.add(jpeg(200, 300));
    await w.close(IsolatePool(tempRoot: dir));
    final pages = (await PdfEngine.inspect(out)).pages;
    expect([for (final p in pages) p.width > p.height], [true, false]);
    Qpdf.check(out);
  });

  test('batches are joined by qpdf, and their files removed', () async {
    final out = '${dir.path}/out.pdf';
    // A tiny batch: every page is its own batch file.
    final w = ImagesPdfWriter(out, workDir: dir, batchBytes: 1);
    for (var i = 0; i < 5; i++) {
      await w.add(jpeg(120 + i, 160));
    }
    expect(await w.close(IsolatePool(tempRoot: dir)), 5);
    expect((await PdfEngine.inspect(out)).pageCount, 5);
    Qpdf.check(out);
    expect(dir.listSync().where((f) => f.path.contains('img2pdf_')), isEmpty);
  });

  test('not an image: damaged, with the page', () async {
    final w = ImagesPdfWriter('${dir.path}/out.pdf', workDir: dir);
    await w.add(jpeg(10, 10));
    await expectLater(
      w.add(Uint8List.fromList('%PDF-1.7 not an image'.codeUnits)),
      throwsA(
        isA<DocError>()
            .having((e) => e.kind, 'kind', DocErrorKind.damaged)
            .having((e) => e.page, 'page', 1),
      ),
    );
  });
}
