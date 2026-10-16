import 'dart:io';

import 'package:doc_core/doc_core.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:test/test.dart';

/// The shared sample corpus (DK-0023), from the repo root.
String fixture(String name) => '../../test/fixtures/$name';

void main() {
  late Directory out;
  setUpAll(pdfrxInitialize);
  setUp(() async => out = await Directory.systemTemp.createTemp('dk_annot_'));
  tearDown(() => out.delete(recursive: true));

  final src = fixture('Invoice INV-2026-014.pdf');
  const red = 0xFFE53935, yellow = 0x80FFEB3B;

  Future<List<PageAnnot>> roundTrip(List<PdfAnnot> add) async {
    final done = '${out.path}/out.pdf';
    await PdfAnnotations.apply(src, done, {0: PageAnnotEdits(add: add)});
    return PdfAnnotations.read(done, 0);
  }

  test('a signature goes into the page: its image where it was placed '
      '(within 1 pt), the date as text beside it (DK-0328)', () async {
    final sig = img.Image(width: 300, height: 100, numChannels: 4);
    img.drawLine(
      sig,
      x1: 10,
      y1: 80,
      x2: 290,
      y2: 20,
      color: img.ColorRgba8(0, 0, 0, 255),
      thickness: 4,
    );
    const rect = (left: 200.0, top: 420.0, right: 350.0, bottom: 370.0);
    final done = '${out.path}/signed.pdf';
    await PdfAnnotations.apply(src, done, {
      0: PageAnnotEdits(
        add: [StampAnnot(rect, img.encodePng(sig), date: '15.10.2026')],
      ),
    });
    expect(await PdfAnnotations.read(done, 0), isEmpty, reason: 'content');
    final images = await PdfEngine.images(done, 0);
    final placed = images.where(
      (i) =>
          (i.box.left - rect.left).abs() < 1 &&
          (i.box.top - rect.top).abs() < 1,
    );
    expect(placed, hasLength(1));
    expect(placed.single.box.right, closeTo(rect.right, 1));
    expect(placed.single.box.bottom, closeTo(rect.bottom, 1));
    expect((await PdfEngine.pageText(done, 0)).text, contains('15.10.2026'));
  });

  test('the corpus page starts without annotations', () async {
    expect(await PdfAnnotations.read(src, 0), isEmpty);
  });

  test('ink: strokes, width and colour survive', () async {
    final read = await roundTrip([
      const InkAnnot(
        [
          [(x: 100, y: 500), (x: 150, y: 520), (x: 200, y: 500)],
          [(x: 100, y: 450), (x: 200, y: 450)],
        ],
        width: 3,
        color: red,
        note: 'Signed here',
      ),
    ]);
    final ink = read.single.annot as InkAnnot;
    expect(ink.strokes, hasLength(2));
    expect(ink.strokes.first, hasLength(3));
    expect(ink.strokes.first[1].x, closeTo(150, 0.01));
    expect(ink.width, closeTo(3, 0.01));
    expect(ink.color & 0xFFFFFF, red & 0xFFFFFF);
    expect(ink.note, 'Signed here');
  });

  test('ink has an appearance: the page shows the stroke', () async {
    final done = '${out.path}/ink.pdf';
    await PdfAnnotations.apply(src, done, {
      0: const PageAnnotEdits(
        add: [
          InkAnnot(
            [
              [(x: 300, y: 300), (x: 500, y: 300)],
            ],
            width: 12,
            color: 0xFFFF0000,
          ),
        ],
      ),
    });
    // 72 dpi: one pixel per point; y from the top of the A4 page.
    final page = await PdfEngine.render(done, 0, dpi: 72);
    final x = 400, y = (page.height - 300).round();
    final i = (y * page.width + x) * 4; // BGRA
    expect((page.bgra[i + 2], page.bgra[i + 1], page.bgra[i]), (255, 0, 0));
  });

  test('underline and strike on sideways text run along the line, not '
      'across the page (DK-1138)', () async {
    // A line reading up the page, x 100..112, y 200..400: the letters'
    // feet are on the right (x 112), their middle at x 106.
    const lb = (x: 100.0, y: 200.0), lt = (x: 100.0, y: 400.0);
    const rb = (x: 112.0, y: 200.0), rt = (x: 112.0, y: 400.0);
    for (final (kind, x) in [
      (MarkupKind.underline, 112),
      (MarkupKind.strikeOut, 106),
    ]) {
      final done = '${out.path}/${kind.name}.pdf';
      await PdfAnnotations.apply(src, done, {
        0: PageAnnotEdits(
          add: [
            MarkupAnnot(kind, [(lb, lt, rb, rt)], color: red),
          ],
        ),
      });
      final page = await PdfEngine.render(done, 0, dpi: 72);
      // The red pixels in the band around the line, as page coordinates.
      final xs = <int>{}, ys = <int>{};
      for (var py = 180; py < 420; py++) {
        for (var px = 90; px < 125; px++) {
          final i = ((page.height - py) * page.width + px) * 4; // BGRA
          // A 1 pt line is anti-aliased: reddish, not pure red.
          if (page.bgra[i + 2] - page.bgra[i + 1] > 40) {
            xs.add(px);
            ys.add(py);
          }
        }
      }
      expect(xs, everyElement(inInclusiveRange(x - 2, x + 1)), reason: '$kind');
      expect(ys.length, greaterThan(180), reason: '$kind runs the line');
    }
  });

  test('markup: highlight with its quads and opacity', () async {
    final read = await roundTrip([
      const MarkupAnnot(MarkupKind.highlight, [
        ((x: 72, y: 700), (x: 300, y: 700), (x: 72, y: 686), (x: 300, y: 686)),
        ((x: 72, y: 680), (x: 200, y: 680), (x: 72, y: 666), (x: 200, y: 666)),
      ], color: yellow),
      const MarkupAnnot(MarkupKind.strikeOut, [
        ((x: 72, y: 600), (x: 150, y: 600), (x: 72, y: 588), (x: 150, y: 588)),
      ], color: red),
    ]);
    final hi = read[0].annot as MarkupAnnot;
    expect(hi.kind, MarkupKind.highlight);
    expect(hi.quads, hasLength(2));
    expect(hi.quads.first.$2.x, closeTo(300, 0.01));
    expect(hi.color >> 24 & 0xFF, 0x80, reason: 'the alpha is the opacity');
    expect((read[1].annot as MarkupAnnot).kind, MarkupKind.strikeOut);
  });

  test('shapes: rectangle with a fill, ellipse without', () async {
    final read = await roundTrip([
      const ShapeAnnot(
        ShapeKind.square,
        (left: 100, top: 400, right: 250, bottom: 300),
        width: 2,
        color: red,
        fill: 0xFF2251E6,
      ),
      const ShapeAnnot(
        ShapeKind.circle,
        (left: 300, top: 400, right: 400, bottom: 320),
        width: 1,
        color: red,
      ),
    ]);
    final sq = read[0].annot as ShapeAnnot;
    expect(sq.kind, ShapeKind.square);
    expect(sq.rect.left, closeTo(100, 0.01));
    expect(sq.rect.top, closeTo(400, 0.01));
    expect(sq.fill! & 0xFFFFFF, 0x2251E6);
    final ci = read[1].annot as ShapeAnnot;
    expect(ci.kind, ShapeKind.circle);
    expect(ci.fill, isNull);
  });

  test('free text and a note', () async {
    final read = await roundTrip([
      const FreeTextAnnot(
        (left: 100, top: 250, right: 300, bottom: 220),
        'Bitte prüfen – Größe',
        fontSize: 14,
        color: 0xFF2251E6,
      ),
      const NoteAnnot(
        (x: 500, y: 780),
        note: 'Ask about the VAT',
        color: 0xFFFFC107,
      ),
    ]);
    final text = read[0].annot as FreeTextAnnot;
    expect(text.text, 'Bitte prüfen – Größe');
    expect(text.fontSize, closeTo(14, 0.01));
    expect(text.color & 0xFFFFFF, 0x2251E6);
    final note = read[1].annot as NoteAnnot;
    expect(note.note, 'Ask about the VAT');
    expect(note.at.x, closeTo(500, 0.01));
  });

  test('remove by index; an edit is a remove plus an add', () async {
    final first = '${out.path}/first.pdf', second = '${out.path}/second.pdf';
    await PdfAnnotations.apply(src, first, {
      0: const PageAnnotEdits(
        add: [
          NoteAnnot((x: 100, y: 100), note: 'one', color: red),
          NoteAnnot((x: 200, y: 100), note: 'two', color: red),
          NoteAnnot((x: 300, y: 100), note: 'three', color: red),
        ],
      ),
    });
    await PdfAnnotations.apply(first, second, {
      0: const PageAnnotEdits(
        remove: {0, 2},
        add: [NoteAnnot((x: 300, y: 120), note: 'three, moved', color: red)],
      ),
    });
    final notes = [
      for (final a in await PdfAnnotations.read(second, 0))
        (a.annot as NoteAnnot).note,
    ];
    expect(notes, ['two', 'three, moved']);
  });

  test('refuses a missing index or page, and writes nothing', () async {
    final done = '${out.path}/nope.pdf';
    for (final edits in [
      {
        0: const PageAnnotEdits(remove: {3}),
      },
      {
        9: const PageAnnotEdits(
          add: [NoteAnnot((x: 1, y: 1), note: 'x', color: red)],
        ),
      },
    ]) {
      await expectLater(
        PdfAnnotations.apply(src, done, edits),
        throwsA(isA<DocError>()),
      );
      expect(File(done).existsSync(), isFalse);
    }
  });

  test('bounds follow the content', () {
    const ink = InkAnnot(
      [
        [(x: 10, y: 20), (x: 30, y: 5)],
      ],
      width: 4,
      color: red,
    );
    expect(ink.bounds, (left: 7.0, top: 23.0, right: 33.0, bottom: 2.0));
  });
}
