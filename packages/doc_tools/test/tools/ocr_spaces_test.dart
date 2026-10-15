import 'dart:io';

import 'package:doc_core/doc_core.dart';
import 'package:doc_vision/doc_vision.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:test/test.dart';

import '../../../doc_vision/test/ocr/python_onnx_runner.dart';

const letter = [
  'Stadtwerke Musterstadt',
  'Herrn Max Mustermann',
  'Musterstraße 12',
  '80331 München',
  'Jahresabrechnung Strom 2025',
  'Sehr geehrter Herr Mustermann,',
  'Zahlungen bitte auf IBAN DE00 0000 0000 0000 0000 00.',
  'Mit freundlichen Grüßen',
  'Seite 1 von 2',
];

/// DK-1109: PP-OCRv5 reads a narrow word gap as no space ('Musterstraße12',
/// 'SehrgeehrterHerr'); the line image's gaps put the spaces back. The
/// device check's letter (DK-1052), scanned the same way, read with the real
/// models through python onnxruntime: every line exactly.
void main() {
  setUpAll(pdfrxInitialize);

  test('a scanned letter reads every line exactly, its spaces too', () async {
    final repo = Directory.current.parent.parent.path;
    final dir = Directory.systemTemp.createTempSync('dk_ocr_spaces_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final typeset = pw.Document()
      ..addPage(
        pw.Page(
          pageFormat: pdf.PdfPageFormat.a4,
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final line in letter)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 18),
                  child: pw.Text(line, style: const pw.TextStyle(fontSize: 13)),
                ),
            ],
          ),
        ),
      );
    final typed = '${dir.path}/typed.pdf';
    await File(typed).writeAsBytes(await typeset.save());
    final shot = await PdfEngine.render(typed, 0, dpi: 150);
    final jpeg = img.encodeJpg(
      img.Image.fromBytes(
        width: shot.width,
        height: shot.height,
        bytes: shot.bgra.buffer,
        numChannels: 4,
        order: img.ChannelOrder.bgra,
      ),
      quality: 85,
    );
    final scan = pw.Document()
      ..addPage(
        pw.Page(
          pageFormat: pdf.PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(pw.MemoryImage(jpeg), fit: pw.BoxFit.fill),
        ),
      );
    final scanned = '${dir.path}/scan.pdf';
    await File(scanned).writeAsBytes(await scan.save());
    final page = await PdfEngine.render(scanned, 0, dpi: 300);
    final runner = await PythonOnnxRunner.start(repo);
    if (runner == null) {
      markTestSkipped(
        'needs tools/fetch_ocr_models.py and `pip install onnxruntime numpy`',
      );
      return;
    }
    addTearDown(runner.close);
    final dictionary = File(
      '$repo/packages/doc_vision/assets/ocr/ppocrv5_latin_dict.txt',
    ).readAsLinesSync();
    final lines = await PpOcr(
      runner,
      dictionary,
    ).recognize(Raster.fromBgra(page.width, page.height, page.bgra));
    final texts = lines.map((l) => l.text).toList();
    printOnFailure(texts.join('\n'));
    expect(texts, containsAll(letter));
  }, timeout: const Timeout(Duration(minutes: 4)));
}
