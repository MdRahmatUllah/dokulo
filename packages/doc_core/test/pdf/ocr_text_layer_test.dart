import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:test/test.dart';

const a4 = PageInfo(width: 595.28, height: 841.89, quarterTurns: 0);

/// The words as the OCR facade would report them on an A4 scan.
const words = [
  LayerWord('Grundmiete', (left: 0.10, top: 0.20, width: 0.20, height: 0.02)),
  LayerWord('1.240,00', (left: 0.40, top: 0.20, width: 0.12, height: 0.02)),
  LayerWord('Grüße', (left: 0.10, top: 0.50, width: 0.10, height: 0.02)),
];

void main() {
  setUpAll(pdfrxInitialize);
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('dk_layer_'));
  tearDown(() async => dir.delete(recursive: true));

  Future<String> write(
    List<PageInfo> pages,
    Map<int, List<LayerWord>> w,
  ) async {
    final path = '${dir.path}/overlay.pdf';
    await File(path).writeAsBytes(await OcrTextLayer.overlay(pages, w));
    return path;
  }

  test('one overlay page per page, the size the page is shown at', () async {
    final landscape = PageInfo(
      width: a4.height,
      height: a4.width,
      quarterTurns: 1,
    );
    final path = await write([a4, landscape], {0: words});
    final info = await PdfEngine.inspect(path);
    expect(info.pageCount, 2);
    expect(info.pages[1].width, closeTo(841.89, 0.5));
    expect((await PdfEngine.pageText(path, 1)).text.trim(), isEmpty);
  });

  test('every word is text, inside its box', () async {
    final path = await write([a4], {0: words});
    final page = await PdfEngine.pageText(path, 0);
    for (final w in words) {
      expect(page.text, contains(w.text));
      final start = page.text.indexOf(w.text);
      final boxes = page.charBoxes.sublist(start, start + w.text.length);
      final left = w.box.left * a4.width,
          right = (w.box.left + w.box.width) * a4.width;
      final top = a4.height - w.box.top * a4.height;
      final bottom = a4.height - (w.box.top + w.box.height) * a4.height;
      const slack = 2.0; // points
      expect(boxes.first.left, closeTo(left, slack), reason: '${w.text} left');
      expect(
        boxes.last.right,
        closeTo(right, slack),
        reason: '${w.text} right',
      );
      for (final b in boxes) {
        expect(b.top, lessThanOrEqualTo(top + slack), reason: '${w.text} top');
        expect(
          b.bottom,
          greaterThanOrEqualTo(bottom - slack),
          reason: '${w.text} bottom',
        );
      }
    }
  });

  test(
    'words on a line keep their spaces when the text is read (DK-1071)',
    () async {
      // Laid out the way the OCR facade's wordsOf does: each word its share of
      // the line by characters, a one-character gap between them.
      const line = 'Herrn Max Mustermann';
      const perChar = 0.4 / line.length;
      var offset = 0;
      final onLine = [
        for (final part in line.split(' '))
          () {
            final start = line.indexOf(part, offset);
            offset = start + part.length;
            return LayerWord(part, (
              left: 0.1 + start * perChar,
              top: 0.3,
              width: part.length * perChar,
              height: 0.02,
            ));
          }(),
      ];
      final path = await write([a4], {0: onLine});
      expect((await PdfEngine.pageText(path, 0)).text, contains(line));
    },
  );

  test('the text is invisible: the page renders blank', () async {
    final path = await write([a4], {0: words});
    final image = await PdfEngine.render(path, 0, dpi: 72);
    expect(image.bgra.every((b) => b == 255), isTrue);
  });

  test('characters outside Latin-1 become "?", German stays', () {
    expect(OcrTextLayer.encodable('Grüße, Straße'), 'Grüße, Straße');
    expect(OcrTextLayer.encodable('Москва €'), '?????? ?');
  });

  group('over a real page, at every rotation', () {
    final invoice =
        '${Directory.current.path}/../../test/fixtures/Invoice INV-2026-014.pdf';

    for (final turns in [0, 1, 2, 3]) {
      test(
        '$turns quarter turn(s): the words land where the OCR saw them',
        () async {
          final rotated = '${dir.path}/rotated.pdf';
          await PdfEngine.assemble([
            PageSource(invoice, 0, addQuarterTurns: turns),
          ], rotated);
          final overlay = await OcrTextLayer.writeOverlay(rotated, {
            0: words,
          }, '${dir.path}/layer.pdf');
          final output = '${dir.path}/searchable.pdf';
          final pool = IsolatePool(tempRoot: dir);
          await pool.run(Lane.qpdf, _apply, (rotated, overlay, output)).result;

          final shown = (await PdfEngine.inspect(output)).pages.single;
          expect(shown.quarterTurns, turns);
          final page = await PdfEngine.pageText(output, 0);
          expect(
            page.text,
            contains('Invoice INV-2026-014'),
          ); // the original stays
          for (final w in words) {
            final start = page.text.indexOf(w.text);
            expect(start, isNot(-1), reason: w.text);
            final mid = page.charBoxes[start + w.text.length ~/ 2];
            final (x, y) = shownAt(
              ((mid.left + mid.right) / 2, (mid.top + mid.bottom) / 2),
              turns,
              shown,
            );
            // The middle character's centre, as a fraction of the page shown.
            expect(
              x,
              inInclusiveRange(w.box.left, w.box.left + w.box.width),
              reason: '${w.text} x',
            );
            expect(
              y,
              inInclusiveRange(w.box.top, w.box.top + w.box.height),
              reason: '${w.text} y',
            );
          }
        },
      );
    }
  });
}

List<String> _apply((String, String, String) files, JobContext context) =>
    OcrTextLayer.apply(files.$1, files.$2, files.$3);

/// A point in PDF space (unrotated, origin bottom-left) as a fraction of the
/// page as shown (after [turns] clockwise quarter turns, origin top-left).
(double, double) shownAt((double, double) point, int turns, PageInfo shown) {
  final (x, y) = point;
  // The unrotated page's size: a quarter turn swaps width and height.
  final (w0, h0) = turns.isOdd
      ? (shown.height, shown.width)
      : (shown.width, shown.height);
  final (dx, dy) = switch (turns) {
    0 => (x, h0 - y),
    1 => (y, x),
    2 => (w0 - x, y),
    _ => (h0 - y, w0 - x),
  };
  return (dx / shown.width, dy / shown.height);
}
