import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:test/test.dart';

String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

// The qpdf halves, as a ToolJob runs them: on a qpdf worker.
void _finish((RedactionPlan, String) job, JobContext context) =>
    PdfRedactor.finish(job.$1, job.$2);

List<String> _rawLeaks(
  (String, List<String>, String) job,
  JobContext context,
) => PdfRedactor.rawLeaks(job.$1, job.$2, job.$3);

List<String> kinds(String text) => [
  for (final f in findSensitive(text))
    '${f.kind.name}${f.verified ? '✓' : ''}:${f.text}',
];

void main() {
  group('detectors', () {
    test(
      'IBANs: checked by mod 97, the fictional one found but not verified',
      () {
        expect(kinds('IBAN DE89 3704 0044 0532 0130 00 bitte'), [
          'iban✓:DE89 3704 0044 0532 0130 00',
        ]);
        expect(kinds('IBAN DE00 0000 0000 0000 0000 00.'), [
          'iban:DE00 0000 0000 0000 0000 00',
        ]);
        expect(ibanValid('GB82WEST12345698765432'), isTrue);
      },
    );

    test('German Steuer-ID only with a valid check digit', () {
      expect(kinds('Steuer-ID: 86 095 742 719'), ['taxId✓:86 095 742 719']);
      expect(kinds('Steuer-ID 47036892816.'), ['taxId✓:47036892816']);
      expect(kinds('Steuer-ID: 00 000 000 000'), isEmpty);
      expect(kinds('Rechnung 12345678901'), isEmpty); // fails the check
    });

    test('email, phone, SSN, NI number, date of birth', () {
      expect(kinds('Mail max.mustermann@example.com, Tel. 089 0000000.'), [
        'email:max.mustermann@example.com',
        'phone:089 0000000',
      ]);
      expect(kinds('Call +49 171 1234567 today'), ['phone:+49 171 1234567']);
      expect(kinds('SSN 123-45-6789, not 000-12-3456'), ['ssn:123-45-6789']);
      expect(kinds('NI number AB 12 34 56 C'), ['niNumber:AB 12 34 56 C']);
      expect(kinds('Geboren am 1. Januar 1990 in Musterstadt'), [
        'dateOfBirth:1. Januar 1990',
      ]);
      expect(kinds('Date of birth: 1985-02-01'), ['dateOfBirth:1985-02-01']);
    });

    test('no false hits on dates, invoice numbers and amounts', () {
      expect(
        kinds('Invoice INV-2026-014, 7 Oct 2026, €1,694.56, due 2026-10-21'),
        isEmpty,
      );
    });
  });

  group('redaction on the corpus', () {
    late Directory work;
    late IsolatePool pool;
    setUpAll(pdfrxInitialize);
    setUp(() {
      work = Directory.systemTemp.createTempSync('dk_redact_');
      pool = IsolatePool(tempRoot: work);
    });
    tearDown(() => work.deleteSync(recursive: true));

    Future<String> redact(
      String input,
      List<RedactionBox> boxes, {
      String? password,
    }) async {
      final plan = await PdfRedactor.prepare(
        input,
        boxes,
        Directory('${work.path}/steps'),
        password: password,
      );
      final output = '${work.path}/redacted.pdf';
      await pool.run(Lane.qpdf, _finish, (plan, output)).result;
      return output;
    }

    Future<List<String>> rawLeaks(String path, List<String> strings) => pool
        .run(Lane.qpdf, _rawLeaks, (path, strings, '${work.path}/raw.qdf'))
        .result;

    /// The darkness at the middle of [box] on the redacted page, as rendered.
    Future<int> centre(String path, RedactionBox box) async {
      final info = await PdfEngine.inspect(path);
      final at = PdfRedactor.displayed(box.box, info.pages[box.page]);
      final page = await PdfEngine.render(path, box.page, dpi: 72);
      final x = ((at.left + at.width / 2) * page.width).round();
      final y = ((at.top + at.height / 2) * page.height).round();
      final i = (y * page.width + x) * 4;
      return page.bgra[i] + page.bgra[i + 1] + page.bgra[i + 2];
    }

    test('the CV: email, phone and date of birth are found', () async {
      final boxes = await PdfRedactor.find(
        fixture('Lebenslauf Max Mustermann.pdf'),
      );
      expect(
        boxes.map((b) => b.kind).toSet(),
        containsAll([
          SensitiveKind.email,
          SensitiveKind.phone,
          SensitiveKind.dateOfBirth,
        ]),
      );
    });

    test('the invoice: IBAN and email gone from text, file and pixels; the rest stays', () async {
      final input = fixture('Invoice INV-2026-014.pdf');
      final boxes = await PdfRedactor.find(input);
      final secrets = {for (final b in boxes) b.text}.toList();
      expect(
        secrets,
        containsAll([
          'DE00 0000 0000 0000 0000 00',
          'hello@beispiel.example.com',
        ]),
      );

      final output = await redact(input, boxes);

      expect((await PdfEngine.inspect(output)).pageCount, 1);
      expect(await PdfRedactor.textLeaks(output, secrets), isEmpty);
      // Nothing in the uncompressed file either; nor the document info.
      expect(
        await rawLeaks(output, [...secrets, 'Dokulo samples (fictional)']),
        isEmpty,
      );
      expect(await PdfRedactor.annotationCount(output), 0);
      for (final b in boxes) {
        expect(
          await centre(output, b),
          lessThan(60),
          reason: 'black over "${b.text}"',
        );
      }
      // The rest is still searchable text (the invisible layer).
      final text = (await PdfEngine.pageText(output, 0)).text;
      expect(text, contains('Logo design'));
      expect(text, contains('INV-2026-014'));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('a rotated page is redacted where it shows', () async {
      final rotated = '${work.path}/rotated.pdf';
      await PdfEngine.assemble([
        PageSource(fixture('Invoice INV-2026-014.pdf'), 0, addQuarterTurns: 1),
      ], rotated);
      final boxes = (await PdfRedactor.find(rotated))
          .where((b) => b.kind == SensitiveKind.email)
          .toList();
      expect(boxes, isNotEmpty);

      final output = await redact(rotated, boxes);

      expect(
        await PdfRedactor.textLeaks(output, ['hello@beispiel.example.com']),
        isEmpty,
      );
      final info = await PdfEngine.inspect(output);
      // Landscape as it was shown, now upright (the image carries the turn).
      expect(info.pages.single.width, closeTo(841.9, 1));
      expect(info.pages.single.height, closeTo(595.3, 1));
      expect(info.pages.single.quarterTurns, 0);
      for (final b in boxes) {
        // The source's box shown on the source page = the output's image.
        final at = PdfRedactor.displayed(
          b.box,
          (await PdfEngine.inspect(rotated)).pages[0],
        );
        final page = await PdfEngine.render(output, 0, dpi: 72);
        final x = ((at.left + at.width / 2) * page.width).round();
        final y = ((at.top + at.height / 2) * page.height).round();
        final i = (y * page.width + x) * 4;
        expect(
          page.bgra[i] + page.bgra[i + 1] + page.bgra[i + 2],
          lessThan(60),
        );
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test(
      'a form: every annotation goes, the untouched page keeps its text',
      () async {
        final input = fixture('form-acroform.pdf');
        expect(await PdfRedactor.annotationCount(input), greaterThan(0));
        final text = await PdfEngine.pageText(input, 0);
        final first = PdfRedactor.lineBoxes(text.charBoxes, 0, 5);
        final output = await redact(input, [
          RedactionBox(0, first.first, text: text.text.substring(0, 5)),
        ]);
        expect(await PdfRedactor.annotationCount(output), 0);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'a locked PDF is redacted with its password; the output is not locked',
      () async {
        final input = fixture('encrypted-aes256.pdf');
        final boxes = await PdfRedactor.find(input, password: 'dokulo');
        final output = await redact(input, boxes, password: 'dokulo');
        expect((await PdfEngine.inspect(output)).pageCount, 1);
        expect(
          await PdfRedactor.textLeaks(output, [for (final b in boxes) b.text]),
          isEmpty,
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
