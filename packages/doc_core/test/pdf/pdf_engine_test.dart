import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:doc_core/doc_core.dart';
import 'package:pdf/pdf.dart' as pw;
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:test/test.dart';

/// The shared sample corpus (DK-0023), from the repo root.
String fixture(String name) => '../../test/fixtures/$name';

void main() {
  late Directory out;
  setUpAll(pdfrxInitialize);
  setUp(() async => out = await Directory.systemTemp.createTemp('dk_pdf_'));
  tearDown(() => out.delete(recursive: true));

  const corpus = {
    'Mietvertrag Musterstraße 12.pdf': 3,
    'Invoice INV-2026-014.pdf': 1,
    'Lebenslauf Max Mustermann.pdf': 2,
    'Finanzamt München – Bescheid 2025.pdf': 1,
    'scanned-letters-bundle.pdf': 6,
    'form-acroform.pdf': 1,
    'form-xfa.pdf': 1,
    'long-300-pages.pdf': 300,
  };

  group('every corpus file opens, renders and yields text', () {
    for (final MapEntry(key: name, value: pages) in corpus.entries) {
      test(name, () async {
        final info = await PdfEngine.inspect(fixture(name));
        expect(info.pageCount, pages);
        // A4 portrait, give or take a point.
        expect(info.pages.first.width, closeTo(595.3, 1));
        expect(info.pages.first.height, closeTo(841.9, 1));

        final page = await PdfEngine.render(fixture(name), 0, dpi: 36);
        expect((page.width, page.height), (298, 421));
        expect(page.bgra, hasLength(298 * 421 * 4));
        expect(
          page.bgra.any((b) => b < 200),
          isTrue,
          reason: 'something is drawn',
        );

        final text = await PdfEngine.pageText(fixture(name), 0);
        expect(text.charBoxes, hasLength(text.text.length));
      });
    }
  });

  test('a locked PDF needs its password', () async {
    final locked = fixture('encrypted-aes256.pdf');
    await expectLater(
      PdfEngine.inspect(locked),
      throwsA(
        isA<DocError>().having((e) => e.kind, 'kind', DocErrorKind.locked),
      ),
    );
    await expectLater(
      PdfEngine.inspect(locked, password: 'wrong'),
      throwsA(
        isA<DocError>().having((e) => e.kind, 'kind', DocErrorKind.locked),
      ),
    );
    expect((await PdfEngine.inspect(locked, password: 'dokulo')).pageCount, 1);
  });

  test('a missing file is a damaged-file error', () async {
    await expectLater(
      PdfEngine.inspect(fixture('no-such.pdf')),
      throwsA(
        isA<DocError>().having((e) => e.kind, 'kind', DocErrorKind.damaged),
      ),
    );
  });

  test('the damaged-xref file opens (PDFium rebuilds the xref)', () async {
    expect((await PdfEngine.inspect(fixture('damaged-xref.pdf'))).pageCount, 1);
  });

  test('outline: the bookmarks as a tree, 0-based pages (DK-0309)', () async {
    final doc = pw.PdfDocument();
    final pages = [
      for (var i = 0; i < 3; i++)
        pw.PdfPage(doc, pageFormat: pw.PdfPageFormat.a4),
    ];
    final intro = pw.PdfOutline(doc, title: 'Intro', dest: pages[0]);
    final terms = pw.PdfOutline(doc, title: 'Terms', dest: pages[1])
      ..add(pw.PdfOutline(doc, title: '§ 3 Rent', dest: pages[2]));
    doc.outline
      ..add(intro)
      ..add(terms);
    final dir = Directory.systemTemp.createTempSync('dk_outline_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/outline.pdf';
    File(path).writeAsBytesSync(await doc.save());

    final outline = await PdfEngine.outline(path);
    expect(
      [for (final e in outline) (e.title, e.page)],
      [('Intro', 0), ('Terms', 1)],
    );
    expect(outline[1].children.single.title, '§ 3 Rent');
    expect(outline[1].children.single.page, 2);
    expect(await PdfEngine.outline(fixture('Invoice INV-2026-014.pdf')), []);
  });

  test('pageTexts: every page in one open, the same text as pageText '
      '(DK-1064)', () async {
    final path = fixture('scanned-letters-bundle.pdf');
    final all = await PdfEngine.pageTexts(path);
    expect(all, hasLength((await PdfEngine.inspect(path)).pageCount));
    for (final (p, text) in all.indexed) {
      expect(text, (await PdfEngine.pageText(path, p)).text);
    }
  });

  test('text comes with one box per character, on the page', () async {
    final text = await PdfEngine.pageText(
      fixture('Invoice INV-2026-014.pdf'),
      0,
    );
    expect(text.text, contains('INV-2026-014'));
    final i = text.text.indexOf('INV-2026-014');
    final box = text.charBoxes[i];
    expect(box.right, greaterThan(box.left));
    expect(box.top, greaterThan(box.bottom));
    expect(box.left, inInclusiveRange(0, 595.3));
    expect(box.top, inInclusiveRange(0, 841.9));
  });

  test(
    'assemble merges, picks, reorders and rotates, never touching the sources',
    () async {
      final invoice = fixture('Invoice INV-2026-014.pdf');
      final long = fixture('long-300-pages.pdf');
      final before = [
        for (final f in [invoice, long])
          sha256.convert(File(f).readAsBytesSync()),
      ];

      final target = '${out.path}/assembled.pdf';
      await PdfEngine.assemble([
        PageSource(long, 41),
        PageSource(invoice, 0, addQuarterTurns: 1),
        PageSource(long, 0),
      ], target);

      final info = await PdfEngine.inspect(target);
      expect(info.pageCount, 3);
      expect(info.pages[1].quarterTurns, 1);
      expect(info.pages[1].width, closeTo(841.9, 1));
      expect(info.pages[1].height, closeTo(595.3, 1));
      expect(
        (await PdfEngine.pageText(target, 0)).text,
        contains('Abschnitt042'),
      );
      expect(
        (await PdfEngine.pageText(target, 1)).text,
        contains('INV-2026-014'),
      );
      expect(
        (await PdfEngine.pageText(target, 2)).text,
        contains('Abschnitt001'),
      );

      final after = [
        for (final f in [invoice, long])
          sha256.convert(File(f).readAsBytesSync()),
      ];
      expect(after, before);
    },
  );

  test('assemble from a locked PDF with its password', () async {
    final target = '${out.path}/unlocked.pdf';
    final locked = fixture('encrypted-aes256.pdf');
    await PdfEngine.assemble(
      [PageSource(locked, 0)],
      target,
      passwords: {locked: 'dokulo'},
    );
    expect(
      (await PdfEngine.pageText(target, 0)).text,
      contains('INV-2026-014'),
    );
  });

  test('a page out of range is an error, not a crash', () async {
    await expectLater(
      PdfEngine.render(fixture('Invoice INV-2026-014.pdf'), 3, dpi: 72),
      throwsA(isA<DocError>().having((e) => e.page, 'page', 3)),
    );
  });

  test('image objects of a scanned page: position and pixel size', () async {
    final images = await PdfEngine.images(
      fixture('scanned-letters-bundle.pdf'),
      0,
    );
    expect(images, isNotEmpty);
    final scan = images.first;
    expect(scan.pixelWidth, greaterThan(500));
    expect(scan.pixelHeight, greaterThan(500));
    expect(scan.box.right - scan.box.left, greaterThan(300));
    expect(
      await PdfEngine.images(fixture('Invoice INV-2026-014.pdf'), 0),
      isEmpty,
    );
  });

  test('image objects work with a non-ASCII file name', () async {
    expect(
      await PdfEngine.images(
        fixture('Finanzamt München – Bescheid 2025.pdf'),
        0,
      ),
      isA<List<ImageObject>>(),
    );
  });

  test('an XFA form is not fillable; an AcroForm is (DK-0614)', () async {
    expect(await PdfEngine.isXfaForm(fixture('form-xfa.pdf')), isTrue);
    expect(await PdfEngine.isXfaForm(fixture('form-acroform.pdf')), isFalse);
    await expectLater(
      PdfEngine.ensureFillable(fixture('form-xfa.pdf')),
      throwsA(
        isA<DocError>().having(
          (e) => e.kind,
          'kind',
          DocErrorKind.unsupportedForm,
        ),
      ),
    );
    await PdfEngine.ensureFillable(fixture('form-acroform.pdf'));
  });
}
