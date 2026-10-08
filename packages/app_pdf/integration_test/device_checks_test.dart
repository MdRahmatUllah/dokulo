// The engines' device checks (DK-1045, DK-1049, DK-1052, DK-1059, DK-1060,
// DK-1061, DK-1063): each engine runs on this device on documents made here (a device
// can't read the repo's fixtures), timed, with peak memory. Run it on the
// shared emulator under `team.py device` (docs/qa/device-lab.md):
//   flutter test integration_test/device_checks_test.dart -d emulator-5554 --flavor dev
// Lines starting "DEVICE |" are the results for the tasks' done messages.
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';
import 'package:qpdf_ffi/qpdf_ffi.dart';

void report(String check, String what, Object value) =>
    debugPrint('DEVICE | $check | $what | $value');

String mb(int bytes) => '${(bytes / 1048576).toStringAsFixed(0)} MB';

/// A text document: a unique word per page ("Abschnitt001"…), and on every
/// page a fictional email and the zero IBAN for redaction to find.
Future<void> textPdf(String path, int pages) async {
  final doc = pw.Document();
  for (var p = 1; p <= pages; p++) {
    final n = p.toString().padLeft(3, '0');
    doc.addPage(
      pw.Page(
        pageFormat: pdf.PdfPageFormat.a4,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Abschnitt$n',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            for (var line = 0; line < 30; line++)
              pw.Text(
                'Zeile $line von Abschnitt$n: Die Miete wird monatlich im Voraus gezahlt.',
              ),
            pw.Text(
              'Kontakt: max.mustermann$n@example.com, IBAN DE00 0000 0000 0000 0000 00',
            ),
          ],
        ),
      ),
    );
  }
  await File(path).writeAsBytes(await doc.save());
}

/// A 300 dpi grey scan: [pages] full-page JPEGs with paper noise.
Future<void> scanPdf(String path, int pages) async {
  final page = img.Image(width: 2480, height: 3508, numChannels: 1);
  final random = Random(7);
  for (final px in page) {
    px.r = 235 + random.nextInt(20);
  }
  for (var y = 300; y < 3200; y += 70) {
    img.fillRect(
      page,
      x1: 250,
      y1: y,
      x2: 2200,
      y2: y + 24,
      color: img.ColorUint8.rgb(40, 40, 40),
    );
  }
  final jpeg = img.encodeJpg(page, quality: 85);
  final doc = pw.Document();
  final image = pw.MemoryImage(Uint8List.fromList(jpeg));
  for (var p = 0; p < pages; p++) {
    doc.addPage(
      pw.Page(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(image, fit: pw.BoxFit.fill),
      ),
    );
  }
  await File(path).writeAsBytes(await doc.save());
}

/// The letter of doc_vision's OCR test (test/fixtures/ocr/letter-de.jpg),
/// whose lines PP-OCRv5 reads on the development machine.
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

/// A scan of [letter]: the lines typeset, rendered at 150 dpi and put back
/// as a page image only (no text layer), [pages] times.
Future<void> letterScan(String dir, String path, int pages) async {
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
  final typed = '$dir/letter-typeset.pdf';
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
  final scan = pw.Document();
  final image = pw.MemoryImage(jpeg);
  for (var p = 0; p < pages; p++) {
    scan.addPage(
      pw.Page(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(image, fit: pw.BoxFit.fill),
      ),
    );
  }
  await File(path).writeAsBytes(await scan.save());
}

List<String> _qpdf((String, String, String) job, JobContext context) =>
    QpdfService.run(
      () => switch (job.$1) {
        'encrypt' => Qpdf.encrypt(job.$2, job.$3, userPassword: 'dokulo'),
        'repair' => Qpdf.repair(job.$2, job.$3),
        _ => Qpdf.compressStructure(job.$2, job.$3),
      },
    );

void _overlay((String, String, String) job, JobContext context) =>
    OcrTextLayer.apply(job.$1, job.$2, job.$3);

void _finish((RedactionPlan, String) job, JobContext context) =>
    PdfRedactor.finish(job.$1, job.$2);

List<String> _raw((String, List<String>, String) job, JobContext context) =>
    PdfRedactor.rawLeaks(job.$1, job.$2, job.$3);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late IsolatePool pool;
  late String text300, scan20;

  setUpAll(() async {
    await pdfrxFlutterInitialize();
    dir = Directory.systemTemp.createTempSync('dk_device_');
    pool = IsolatePool(tempRoot: Directory('${dir.path}/jobs')..createSync());
    text300 = '${dir.path}/text-300.pdf';
    scan20 = '${dir.path}/scan-20.pdf';
    await textPdf(text300, 300);
    await scanPdf(scan20, 20);
    report(
      'device',
      'inputs',
      '${mb(File(text300).lengthSync())} text (300 p), ${mb(File(scan20).lengthSync())} scan (20 p)',
    );
  });
  tearDownAll(() {
    report('device', 'peak memory (RSS)', mb(ProcessInfo.maxRss));
    dir.deleteSync(recursive: true);
  });

  testWidgets('DK-1045: PdfEngine opens 300 pages and renders page 1', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final clock = Stopwatch()..start();
      final info = await PdfEngine.inspect(text300);
      await PdfEngine.render(text300, 0, width: 1080);
      report(
        'DK-1045',
        'open 300 pages + render page 1 (1080 px)',
        '${clock.elapsedMilliseconds} ms',
      );
      expect(info.pageCount, 300);
      clock.reset();
      for (var p = 0; p < 20; p++) {
        await PdfEngine.pageText(text300, p * 15);
      }
      report(
        'DK-1045',
        'pageText per page (20 pages)',
        '${clock.elapsedMilliseconds ~/ 20} ms',
      );
    });
  });

  testWidgets('DK-1049: PdfStructure on 20 pages', (tester) async {
    await tester.runAsync(() async {
      final clock = Stopwatch()..start();
      final blocks = await PdfStructure.extract(
        text300,
        pages: [for (var p = 0; p < 20; p++) p],
      );
      report(
        'DK-1049',
        'structure per page',
        '${clock.elapsedMilliseconds ~/ 20} ms (${blocks.length} blocks)',
      );
      expect(blocks, isNotEmpty);
    });
  });

  testWidgets('DK-1059: qpdf encrypt, repair, compress structure (300 pages)', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final op in ['encrypt', 'repair', 'compress']) {
        final clock = Stopwatch()..start();
        await pool.run(Lane.qpdf, _qpdf, (
          op,
          text300,
          '${dir.path}/$op.pdf',
        )).result;
        report('DK-1059', '$op (300 pages)', '${clock.elapsedMilliseconds} ms');
      }
      for (final op in ['encrypt', 'repair', 'compress']) {
        expect(File('${dir.path}/$op.pdf').existsSync(), isTrue, reason: op);
      }
    });
  });

  testWidgets('DK-1060: the OCR text layer on 20 pages', (tester) async {
    await tester.runAsync(() async {
      final words = {
        for (var p = 0; p < 20; p++)
          p: [
            for (var i = 0; i < 300; i++)
              LayerWord('Wort$i', (
                left: 0.05 + (i % 10) * 0.09,
                top: 0.05 + (i ~/ 10) * 0.03,
                width: 0.08,
                height: 0.02,
              )),
          ],
      };
      final clock = Stopwatch()..start();
      final overlay = await OcrTextLayer.writeOverlay(
        scan20,
        words,
        '${dir.path}/overlay.pdf',
      );
      await pool.run(Lane.qpdf, _overlay, (
        scan20,
        overlay,
        '${dir.path}/layered.pdf',
      )).result;
      report(
        'DK-1060',
        'text layer per page (300 words)',
        '${clock.elapsedMilliseconds ~/ 20} ms',
      );
      expect(
        (await PdfEngine.pageText('${dir.path}/layered.pdf', 3)).text,
        contains('Wort42'),
      );
    });
  });

  testWidgets('DK-1061: redaction of 20 pages, no leaks', (tester) async {
    await tester.runAsync(() async {
      final twenty = '${dir.path}/text-20.pdf';
      await textPdf(twenty, 20);
      final clock = Stopwatch()..start();
      final boxes = await PdfRedactor.find(twenty);
      final plan = await PdfRedactor.prepare(
        twenty,
        boxes,
        Directory('${dir.path}/redact'),
      );
      final out = '${dir.path}/redacted.pdf';
      await pool.run(Lane.qpdf, _finish, (plan, out)).result;
      final pages = boxes.map((b) => b.page).toSet().length;
      report(
        'DK-1061',
        'per redacted page ($pages pages, ${boxes.length} boxes)',
        '${clock.elapsedMilliseconds ~/ pages} ms',
      );
      final secrets = {for (final b in boxes) b.text}.toList();
      expect(await PdfRedactor.textLeaks(out, secrets), isEmpty);
      expect(
        await pool.run(Lane.qpdf, _raw, (
          out,
          secrets,
          '${dir.path}/raw.qdf',
        )).result,
        isEmpty,
      );
      report('DK-1061', 'leaks (text, raw)', 'none');
    });
  });

  testWidgets('DK-1052: Make text searchable reads a letter with PP-OCRv5', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final scan = '${dir.path}/letter-scan.pdf';
      await letterScan(dir.path, scan, 2);
      final out = Directory('${dir.path}/ocr')..createSync();
      final db = DokuloDatabase.memory();
      var peak = ProcessInfo.currentRss;
      final sampler = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (ProcessInfo.currentRss > peak) peak = ProcessInfo.currentRss;
      });
      final before = ProcessInfo.currentRss;
      final clock = Stopwatch()..start();
      final run = await JobQueue(pool, db, ToolRegistry.app()).start(
        'ocr',
        OcrInput(files: [scan], outputDir: out.path, suffix: ' – searchable'),
      );
      final output = await run.result as OneFile;
      clock.stop();
      sampler.cancel();
      await db.close();
      report(
        'DK-1052',
        'ocr per page (2 pages, 300 dpi, PP-OCRv5 on an ONNX worker)',
        '${clock.elapsedMilliseconds ~/ 2} ms',
      );
      report(
        'DK-1052',
        'peak RAM above the start (sessions + one page)',
        mb(peak - before),
      );
      final text = (await PdfEngine.pageText(output.path, 1)).text;
      final missing = [
        for (final line in letter)
          if (!text.contains(line)) line,
      ];
      report('DK-1052', 'lines not read', missing.isEmpty ? 'none' : missing);
      expect(missing, isEmpty);
    });
  });

  testWidgets('DK-1063: Compress PDF, 20-page 300 dpi scan', (tester) async {
    await tester.runAsync(() async {
      for (final preset in CompressPreset.values) {
        final clock = Stopwatch()..start();
        final result = await PdfCompress(pool).compress(
          scan20,
          '${dir.path}/c_${preset.name}.pdf',
          CompressOptions(preset: preset),
        );
        report(
          'DK-1063',
          '${preset.name}: per page',
          '${clock.elapsedMilliseconds ~/ 20} ms, ${mb(result.bytesBefore)} → ${mb(result.bytesAfter)}',
        );
      }
      final clock = Stopwatch()..start();
      final target = File(scan20).lengthSync() ~/ 4;
      final result = await PdfCompress(pool).compress(
        scan20,
        '${dir.path}/c_target.pdf',
        CompressOptions(targetBytes: target),
      );
      report(
        'DK-1063',
        'size target ${mb(target)}',
        '${clock.elapsedMilliseconds} ms, met: ${result.targetMet}',
      );
    });
  });
}
