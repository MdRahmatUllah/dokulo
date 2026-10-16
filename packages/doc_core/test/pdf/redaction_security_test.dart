/// The redaction security suite (DK-0528; Technology plan, "Redaction
/// security"): a release blocker, its own step of tools/check.py. On every
/// kind of input (text PDFs, a scan, a form, an annotated file, an encrypted
/// one) a redaction must leave no trace of what it covered:
///
/// - PDFium's text and the uncompressed file (qpdf QDF) hold none of the
///   redacted strings;
/// - no document info, XMP metadata, annotations, attachments or JavaScript;
/// - the pixels under each box are black;
/// - the file is written out in full (one `%%EOF`, no `/Prev`): never an
///   incremental update that keeps the old content underneath.
@Tags(['redaction-security'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:test/test.dart';

String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

void _finish((RedactionPlan, String) job, JobContext context) =>
    PdfRedactor.finish(job.$1, job.$2);

List<String> _overlay((String, String, String) job, JobContext context) =>
    OcrTextLayer.apply(job.$1, job.$2, job.$3);

/// The secrets tools/make_fixtures.py plants in corpus/hidden-content.pdf
/// (XMP, an embedded file, JavaScript on opening, a page /AA action).
const _hidden = [
  'SECRETXMP4711',
  'SECRETFILE4712',
  'SECRETJS4713',
  'SECRETAA4714',
];

bool _overlaps(Box a, Box b) =>
    a.left < b.right &&
    b.left < a.right &&
    a.bottom < b.top &&
    b.bottom < a.top;

List<String> _rawLeaks(
  (String, List<String>, String) job,
  JobContext context,
) => PdfRedactor.rawLeaks(job.$1, job.$2, job.$3);

List<String> _rawKeys((String, List<String>, String) job, JobContext context) =>
    PdfRedactor.rawLeaks(job.$1, job.$2, job.$3, exact: true);

/// Keys a redacted file must not have anywhere: document info entries,
/// XMP, attachments, scripts and actions that run on opening, annotations.
/// Searched as QDF writes a key, followed by a space, so that the bytes of
/// an image (a scan's JPEG) can't match by chance.
const _forbidden = [
  '/Author',
  '/Creator',
  '/Producer',
  '/Title',
  '/Metadata',
  '/EmbeddedFiles',
  '/JavaScript',
  '/JS',
  '/OpenAction',
  '/AA',
  '/Annots',
];

void main() {
  late Directory work;
  late IsolatePool pool;
  setUpAll(pdfrxInitialize);
  setUp(() {
    work = Directory.systemTemp.createTempSync('dk_redsec_');
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

  Future<List<String>> raw(String path, List<String> strings) => pool.run(
    Lane.qpdf,
    _rawLeaks,
    (path, strings, '${work.path}/raw.qdf'),
  ).result;

  /// Dictionary keys in the uncompressed file ("/AA ").
  Future<List<String>> keys(String path, List<String> keys) => pool.run(
    Lane.qpdf,
    _rawKeys,
    (path, keys, '${work.path}/keys.qdf'),
  ).result;

  /// Every check on one redacted [output]. [secrets] are the covered texts.
  Future<void> secure(
    String input,
    String output,
    List<RedactionBox> boxes,
    List<String> secrets, {
    String? password,
  }) async {
    expect(
      await PdfRedactor.textLeaks(output, secrets),
      isEmpty,
      reason: 'PDFium text',
    );
    expect(
      await raw(output, secrets),
      isEmpty,
      reason: 'the uncompressed file holds no secret',
    );
    expect(
      await keys(output, [for (final k in _forbidden) '$k ']),
      isEmpty,
      reason: 'no info, XMP, files, scripts or annotations',
    );
    expect(await PdfRedactor.annotationCount(output), 0);
    // Not even part of a secret: no character left under any box (a line
    // whose box was missed or misplaced would keep its tail).
    for (final b in boxes) {
      final text = await PdfEngine.pageText(output, b.page);
      final inner = (
        left: b.box.left + 1,
        top: b.box.top - 1,
        right: b.box.right - 1,
        bottom: b.box.bottom + 1,
      );
      for (final (i, c) in text.charBoxes.indexed) {
        if (c.right <= c.left || c.top <= c.bottom) continue;
        expect(
          _overlaps(c, inner),
          isFalse,
          reason:
              'a character ("${text.text[i]}") under the box over '
              '"${b.text}" on page ${b.page + 1}',
        );
      }
    }
    // Written out in full.
    final bytes = File(output).readAsBytesSync();
    final latin = String.fromCharCodes(bytes);
    expect('%%EOF'.allMatches(latin), hasLength(1), reason: 'one revision');
    expect(latin.contains('/Prev'), isFalse, reason: 'no incremental update');
    // Black where the boxes are.
    // Where each box is on the page as displayed: from the input's pages
    // (the output's are rasters, upright).
    final info = await PdfEngine.inspect(input, password: password);
    for (final b in boxes) {
      final at = PdfRedactor.displayed(b.box, info.pages[b.page]);
      final page = await PdfEngine.render(output, b.page, dpi: 72);
      // The centre and, a little inside, the four corners.
      for (final (fx, fy) in [
        (0.5, 0.5),
        (0.1, 0.1),
        (0.9, 0.1),
        (0.1, 0.9),
        (0.9, 0.9),
      ]) {
        final x = ((at.left + at.width * fx) * page.width).round();
        final y = ((at.top + at.height * fy) * page.height).round();
        final i = (y * page.width + x) * 4;
        expect(
          page.bgra[i] + page.bgra[i + 1] + page.bgra[i + 2],
          lessThan(60),
          reason: 'black over "${b.text}" on page ${b.page + 1} at ($fx, $fy)',
        );
      }
    }
  }

  const slow = Timeout(Duration(minutes: 3));

  for (final name in [
    'Invoice INV-2026-014.pdf',
    'Mietvertrag Musterstraße 12.pdf',
    'Lebenslauf Max Mustermann.pdf',
    'Finanzamt München – Bescheid 2025.pdf',
  ]) {
    test('text PDF: $name', () async {
      final input = fixture(name);
      final boxes = await PdfRedactor.find(input);
      expect(boxes, isNotEmpty, reason: 'the corpus has personal data');
      final output = await redact(input, boxes);
      await secure(
        input,
        output,
        boxes,
        {for (final b in boxes) b.text}.toList(),
      );
    }, timeout: slow);
  }

  test('a scan: a box drawn by hand turns the pixels black', () async {
    final input = fixture('scanned-letters-bundle.pdf');
    final page = (await PdfEngine.inspect(input)).pages.first;
    // The letterhead's corner: top left, a fifth of the page across.
    final box = (
      left: 40.0,
      top: page.height - 40,
      right: 40 + page.width / 5,
      bottom: page.height - 120,
    );
    final boxes = [RedactionBox(0, box)];
    final output = await redact(input, boxes);
    await secure(input, output, boxes, const []);
  }, timeout: slow);

  test('a form: the fields and their values go with the annotations', () async {
    final input = fixture('form-acroform.pdf');
    final text = await PdfEngine.pageText(input, 0);
    final first = PdfRedactor.lineBoxes(text.charBoxes, 0, 5);
    final boxes = [
      RedactionBox(0, first.first, text: text.text.substring(0, 5)),
    ];
    final output = await redact(input, boxes);
    await secure(input, output, boxes, [text.text.substring(0, 5)]);
    expect(
      await keys(output, ['/AcroForm ', '/Widget']),
      isEmpty,
      reason: 'no form left to fill in the old values',
    );
  }, timeout: slow);

  test('an annotated file: a note holding a secret leaves with it', () async {
    final annotated = '${work.path}/annotated.pdf';
    const secret = 'Kontonummer DE00 0000 0000 0000 0000 00';
    await PdfAnnotations.apply(fixture('Invoice INV-2026-014.pdf'), annotated, {
      0: PageAnnotEdits(
        add: [
          const NoteAnnot((x: 300, y: 700), note: secret, color: 0xFFFFD000),
        ],
      ),
    });
    expect(await PdfRedactor.annotationCount(annotated), greaterThan(0));
    final boxes = await PdfRedactor.find(annotated);
    final output = await redact(annotated, boxes);
    await secure(annotated, output, boxes, [
      ...{for (final b in boxes) b.text},
      secret,
    ]);
  }, timeout: slow);

  test('an encrypted file: redacted with its password, then open', () async {
    final input = fixture('encrypted-aes256.pdf');
    final boxes = await PdfRedactor.find(input, password: 'dokulo');
    final output = await redact(input, boxes, password: 'dokulo');
    await secure(
      input,
      output,
      boxes,
      {for (final b in boxes) b.text}.toList(),
      password: 'dokulo',
    );
    expect(await keys(output, ['/Encrypt ']), isEmpty);
  }, timeout: slow);

  test('hidden content: XMP, an attachment, scripts and actions go, with '
      'the secrets they hold', () async {
    final input = fixture('corpus/hidden-content.pdf');
    // The input has them all, or this test proves nothing.
    expect(
      await keys(input, [
        '/Metadata ',
        '/EmbeddedFiles ',
        '/OpenAction ',
        '/AA ',
      ]),
      hasLength(4),
    );
    expect(await raw(input, _hidden), hasLength(_hidden.length));
    final boxes = await PdfRedactor.find(input);
    final output = await redact(input, boxes);
    await secure(input, output, boxes, [
      ...{for (final b in boxes) b.text},
      ..._hidden,
    ]);
  }, timeout: slow);

  test('an incremental update: the old revision does not survive', () async {
    final input = fixture('corpus/incremental-update.pdf');
    final latin = String.fromCharCodes(File(input).readAsBytesSync());
    expect('%%EOF'.allMatches(latin), hasLength(2), reason: 'two revisions');
    final boxes = await PdfRedactor.find(input);
    final output = await redact(input, boxes);
    await secure(input, output, boxes, [
      ...{for (final b in boxes) b.text},
      'INV-2026-014 - paid', // the second revision's title
    ]);
  }, timeout: slow);

  test('rotated and cropped pages: a box on every page', () async {
    final input = fixture('corpus/rotated-pages.pdf');
    final boxes = <RedactionBox>[];
    final secrets = <String>[];
    final pages = (await PdfEngine.inspect(input)).pageCount;
    for (var p = 0; p < pages; p++) {
      final text = await PdfEngine.pageText(input, p);
      final words = RegExp(r'\S{4,}').allMatches(text.text).toList();
      if (words.isEmpty) continue;
      final w = words.first;
      for (final box in PdfRedactor.lineBoxes(text.charBoxes, w.start, w.end)) {
        boxes.add(RedactionBox(p, box, text: w.group(0)!));
      }
      secrets.add(w.group(0)!);
    }
    expect(boxes, isNotEmpty);
    final output = await redact(input, boxes);
    await secure(input, output, boxes, secrets);
  }, timeout: slow);

  test('a scan after OCR: the recognised words under a box leave the text '
      'layer too', () async {
    final scan = fixture('scanned-letters-bundle.pdf');
    final ocrd = '${work.path}/ocrd.pdf';
    // The OCR step's result (DK-0394): words over the first page, one of
    // them an IBAN.
    const iban = 'DE89370400440532013000';
    await OcrTextLayer.writeOverlay(scan, {
      0: const [
        LayerWord('Musterfirma', (
          left: 0.1,
          top: 0.1,
          width: 0.25,
          height: 0.03,
        )),
        LayerWord(iban, (left: 0.1, top: 0.2, width: 0.5, height: 0.03)),
      ],
    }, '${work.path}/overlay.pdf');
    await pool.run(Lane.qpdf, _overlay, (
      scan,
      '${work.path}/overlay.pdf',
      ocrd,
    )).result;
    expect((await PdfEngine.pageText(ocrd, 0)).text, contains(iban));
    final boxes = [
      for (final b in await PdfRedactor.find(ocrd))
        if (b.text.replaceAll(' ', '') == iban) b,
    ];
    expect(
      boxes,
      isNotEmpty,
      reason: 'the detector finds the IBAN in the OCR text',
    );
    final output = await redact(ocrd, boxes);
    await secure(ocrd, output, boxes, [iban]);
  }, timeout: slow);

  test('the check itself catches an incremental update', () {
    final twice = Uint8List.fromList(
      '%PDF-1.7\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n'
              'trailer<</Prev 9>>\n%%EOF\n'
          .codeUnits,
    );
    final latin = String.fromCharCodes(twice);
    expect('%%EOF'.allMatches(latin), hasLength(2));
    expect(latin.contains('/Prev'), isTrue);
  });
}
