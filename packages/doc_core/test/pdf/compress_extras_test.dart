import 'dart:io';
import 'dart:typed_data';

import 'package:doc_core/doc_core.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:test/test.dart';

String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

/// A stand-in for OpenCV's encoder.
Future<Uint8List> jpeg(Uint8List rgba, int w, int h, int quality) async =>
    img.encodeJpg(
      img.Image.fromBytes(
        width: w,
        height: h,
        bytes: rgba.buffer,
        numChannels: 4,
      ),
      quality: quality,
    );

void main() {
  setUpAll(pdfrxInitialize);
  late Directory dir;
  setUp(
    () async => dir = await Directory.systemTemp.createTemp('dk_compress_'),
  );
  tearDown(() async => dir.delete(recursive: true));

  group('size target', () {
    // A made-up pipeline: size grows with quality and with resolution².
    int size(CompressLevel l) => l.quality * l.dpi * l.dpi ~/ 100;
    Future<SizeTargetResult> search(int target, List<CompressLevel> log) =>
        searchSizeTarget(
          targetBytes: target,
          tryLevel: (l) async {
            log.add(l);
            return (path: '${l.dpi}-${l.quality}.pdf', bytes: size(l));
          },
        );

    test(
      'the highest quality that fits, at the sharpest resolution that can',
      () async {
        final log = <CompressLevel>[];
        // 200 dpi needs quality < 40 to fit 15,000 bytes (q40 = 16,000); 150 dpi fits up to quality 66 (225 × q).
        final r = await search(15000, log);
        expect(r.fits, isTrue);
        expect(r.level, (quality: 66, dpi: 150));
        expect(size(r.level), lessThanOrEqualTo(15000));
        expect(size((quality: 67, dpi: 150)), greaterThan(15000));
        expect(log.toSet().length, log.length); // nothing tried twice
        expect(r.tries, lessThanOrEqualTo(2 * 7));
      },
    );

    test(
      'a generous target keeps quality 85 at 200 dpi in a few tries',
      () async {
        final r = await search(10000000, []);
        expect(r.level, (quality: 85, dpi: 200));
        expect(r.tries, lessThanOrEqualTo(7));
      },
    );

    test('nothing fits: the smallest try, flagged', () async {
      final r = await search(100, []);
      expect(r.fits, isFalse);
      expect(r.level, (quality: 40, dpi: 72));
    });
  });

  group('raster fallback', () {
    test('pages become JPEG pictures and keep their text', () async {
      final input = fixture('Mietvertrag Musterstraße 12.pdf');
      final output = '${dir.path}/raster.pdf';
      await RasterFallback.rasterise(
        input,
        output,
        [0, 2],
        dpi: 100,
        quality: 60,
        encodeJpeg: jpeg,
        work: dir,
      );

      expect((await PdfEngine.inspect(output)).pageCount, 3);
      expect(
        await PdfEngine.usesUnembeddedFonts(output, 0),
        isFalse,
      ); // a picture now
      expect(
        await PdfEngine.usesUnembeddedFonts(output, 1),
        isTrue,
      ); // untouched
      expect(
        (await PdfEngine.pageText(output, 0)).text,
        contains('Grundmiete'),
      );
      expect(
        (await PdfEngine.images(output, 0)).single.pixelWidth,
        closeTo(827, 2),
      ); // A4 at 100 dpi
    });

    test('a scan at a lower resolution and quality gets smaller', () async {
      final input = fixture('scanned-letters-bundle.pdf');
      final output = '${dir.path}/smaller.pdf';
      await RasterFallback.rasterise(
        input,
        output,
        [0, 1, 2, 3, 4, 5],
        dpi: 72,
        quality: 40,
        encodeJpeg: jpeg,
        work: dir,
      );
      expect(File(output).lengthSync(), lessThan(File(input).lengthSync()));
      expect((await PdfEngine.inspect(output)).pageCount, 6);
    });
  });
}
