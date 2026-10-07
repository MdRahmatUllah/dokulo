import 'dart:io';

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

  test('the text is invisible: the page renders blank', () async {
    final path = await write([a4], {0: words});
    final image = await PdfEngine.render(path, 0, dpi: 72);
    expect(image.bgra.every((b) => b == 255), isTrue);
  });

  test('characters outside Latin-1 become "?", German stays', () {
    expect(OcrTextLayer.encodable('Grüße, Straße'), 'Grüße, Straße');
    expect(OcrTextLayer.encodable('Москва €'), '?????? ?');
  });
}
