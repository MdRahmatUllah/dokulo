import 'package:doc_core/doc_core.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:test/test.dart';

/// Lays out [text] as characters at ([x], [baseline]), 0.5 em wide each.
List<StyledChar> place(
  String text,
  double x,
  double baseline, {
  double size = 11,
  bool bold = false,
}) => [
  for (final (i, ch) in text.split('').indexed)
    StyledChar(
      ch,
      (
        left: x + i * size * 0.5,
        right: x + (i + 1) * size * 0.5,
        bottom: baseline,
        top: baseline + size * 0.7,
      ),
      baseline: baseline,
      fontSize: size,
      bold: bold,
    ),
];

List<Block> layout(List<StyledChar> chars, {double width = 595}) {
  final lines = PdfStructure.buildLines(chars);
  return PdfStructure.blocks(
    lines,
    page: 0,
    pageWidth: width,
    bodySize: PdfStructure.bodySize(chars),
  );
}

void main() {
  group('layout rules', () {
    test('two text columns read column by column, not across', () {
      final chars = <StyledChar>[];
      for (var i = 0; i < 6; i++) {
        final y = 700.0 - i * 15;
        chars
          ..addAll(place('Links Zeile $i des langen Absatzes', 50, y))
          ..addAll(place('Rechts Zeile $i des langen Absatzes', 320, y));
      }
      final text = layout(chars).map((b) => b.text).join('\n');
      expect(
        text.indexOf('Links Zeile 5'),
        lessThan(text.indexOf('Rechts Zeile 0')),
      );
    });

    test('headings by size and by bold; levels by size', () {
      final blocks = layout([
        ...place('Title', 50, 780, size: 20),
        ...place('Section', 50, 740, size: 14),
        ...place('§ 1 Bold heading', 50, 710, bold: true),
        ...place('Body text that is long enough to be a paragraph.', 50, 690),
        ...place('More body text on the second line here.', 50, 676),
      ]);
      expect(blocks.map((b) => (b.kind, b.level)), [
        (BlockKind.heading, 1),
        (BlockKind.heading, 2),
        (BlockKind.heading, 3),
        (BlockKind.paragraph, 0),
      ]);
      expect(
        blocks.last.text,
        'Body text that is long enough to be a paragraph. '
        'More body text on the second line here.',
      );
    });

    test('list items, with their continuation lines', () {
      final blocks = layout([
        ...place('Bring with you:', 50, 700),
        ...place('• the contract', 50, 685),
        ...place('• a photo ID that is', 50, 670),
        ...place('still valid', 60, 655),
        ...place('2) the key', 50, 640),
      ]);
      expect(blocks.map((b) => b.kind), [
        BlockKind.paragraph,
        BlockKind.listItem,
        BlockKind.listItem,
        BlockKind.listItem,
      ]);
      expect(blocks[2].text, '• a photo ID that is still valid');
    });

    test('a hyphenated line end is joined', () {
      final blocks = layout([
        ...place('Die Ver-', 50, 700),
        ...place('träge sind gültig.', 50, 686),
      ]);
      expect(blocks.single.text, 'Die Verträge sind gültig.');
    });

    test('aligned cells over several lines are a table; '
        'a new column count starts a new one', () {
      final blocks = layout([
        ...place('Item', 50, 700),
        ...place('Qty', 250, 700),
        ...place('Amount', 400, 700),
        ...place('Logo', 50, 685),
        ...place('1', 250, 685),
        ...place('850.00', 400, 685),
        ...place('Cards', 50, 670),
        ...place('2', 250, 670),
        ...place('129.00', 400, 670),
        ...place('Net', 300, 640),
        ...place('979.00', 400, 640),
        ...place('Total', 300, 625),
        ...place('1,165.01', 400, 625),
      ]);
      expect(blocks.map((b) => b.kind), [BlockKind.table, BlockKind.table]);
      expect(blocks.first.rows, [
        ['Item', 'Qty', 'Amount'],
        ['Logo', '1', '850.00'],
        ['Cards', '2', '129.00'],
      ]);
      expect(blocks.last.rows.last, ['Total', '1,165.01']);
    });

    test('two text blocks side by side read one after the other', () {
      final blocks = layout([
        ...place('Bill to:', 50, 700),
        ...place('Invoice 14', 330, 700),
        ...place('Max Mustermann', 50, 685),
        ...place('Date: 7 Oct', 330, 685),
      ]);
      expect(blocks.map((b) => (b.kind, b.text)), [
        (BlockKind.paragraph, 'Bill to: Max Mustermann'),
        (BlockKind.paragraph, 'Invoice 14 Date: 7 Oct'),
      ]);
    });

    test('running headers and footers go; one-off lines in the band stay', () {
      List<TextLine> page(int n) => PdfStructure.buildLines([
        ...place('Handbuch · Kapitel $n', 50, 800), // header, digits differ
        ...place('Text of page $n', 50, 500),
        ...place('Seite $n von 3', 250, 30), // page number
        if (n == 1) ...place('Only on page one', 50, 60),
      ]);
      final kept = PdfStructure.dropRunningLines(
        {0: page(1), 1: page(2), 2: page(3)},
        {0: 842, 1: 842, 2: 842},
      );
      expect(kept[0]!.map((l) => l.text), [
        'Text of page 1',
        'Only on page one',
      ]);
      expect(kept[2]!.map((l) => l.text), ['Text of page 3']);
    });
  });

  group('the corpus', () {
    setUpAll(pdfrxInitialize);
    String fixture(String name) => '../../test/fixtures/$name';

    test(
      'rental contract: title, § headings, merged paragraphs, no footer',
      () async {
        final blocks = await PdfStructure.extract(
          fixture('Mietvertrag Musterstraße 12.pdf'),
        );
        final headings = blocks.where((b) => b.kind == BlockKind.heading);
        expect(headings.first.text, 'Mietvertrag für Wohnräume');
        expect(headings.first.level, 1);
        expect(
          headings.map((b) => b.text),
          containsAll(['§ 1 Mietsache', '§ 2 Mietzeit', '§ 3 Miete']),
        );
        expect(blocks.where((b) => b.text.contains('Seite')), isEmpty);
        expect(
          blocks.firstWhere((b) => b.text.startsWith('Zwischen')).text,
          endsWith('wird folgender Vertrag geschlossen.'),
        );
        expect(blocks.map((b) => b.page).toSet(), {0, 1, 2});
      },
    );

    test('invoice: the items table and the totals', () async {
      final blocks = await PdfStructure.extract(
        fixture('Invoice INV-2026-014.pdf'),
      );
      final tables = blocks.where((b) => b.kind == BlockKind.table).toList();
      final items = tables.firstWhere((t) => t.rows.first.first == 'Item');
      expect(items.rows.first, ['Item', 'Qty', 'Unit', 'Amount']);
      expect(items.rows, hasLength(5));
      expect(items.rows[1], ['Logo design', '1', '€850.00', '€850.00']);
      expect(
        tables.any((t) => t.rows.any((r) => r.join(' ') == 'Total €1,694.56')),
        isTrue,
      );
      expect(
        blocks.firstWhere((b) => b.kind == BlockKind.heading).text,
        'Beispiel Design GmbH',
      );
    });

    test(
      'long document: page numbers dropped, chapter headings kept',
      () async {
        final blocks = await PdfStructure.extract(
          fixture('long-300-pages.pdf'),
          pages: [0, 1, 2],
        );
        expect(blocks.where((b) => b.text.startsWith('Seite ')), isEmpty);
        // Larger than the body: headings, though they repeat in the top band
        // (DK-1055).
        expect(
          [
            for (final b in blocks)
              if (b.kind == BlockKind.heading) b.text,
          ],
          [
            'Kapitel 1 · Abschnitt 1',
            'Kapitel 1 · Abschnitt 2',
            'Kapitel 1 · Abschnitt 3',
          ],
        );
        expect(blocks.any((b) => b.text.contains('Abschnitt002.')), isTrue);
      },
    );

    test('heading levels are ranked over the whole document', () async {
      final blocks = await PdfStructure.extract(
        fixture('Mietvertrag Musterstraße 12.pdf'),
      );
      final sections = blocks.where(
        (b) => b.kind == BlockKind.heading && b.text.startsWith('§'),
      );
      expect(sections.map((b) => b.page).toSet(), {0, 1, 2});
      expect(sections.map((b) => b.level).toSet(), {2}); // DK-1057
      expect(blocks.first.level, 1);
    });

    test('side-by-side address blocks are paragraphs, not tables', () async {
      final invoice = await PdfStructure.extract(
        fixture('Invoice INV-2026-014.pdf'),
      );
      final address = invoice.firstWhere((b) => b.text.startsWith('Bill to:'));
      expect(address.kind, BlockKind.paragraph); // DK-1056
      expect(
        address.text,
        'Bill to: Max Mustermann Musterstraße 12 80331 München',
      );
      expect(
        invoice.firstWhere((b) => b.text.startsWith('Invoice INV')).kind,
        BlockKind.paragraph,
      );
      final assessment = await PdfStructure.extract(
        fixture('Finanzamt München – Bescheid 2025.pdf'),
      );
      expect(
        assessment.where(
          (b) => b.kind == BlockKind.table && b.text.contains('Herrn'),
        ),
        isEmpty,
      );
    });

    test('every other corpus file yields blocks without failing', () async {
      for (final name in [
        'Lebenslauf Max Mustermann.pdf',
        'Finanzamt München – Bescheid 2025.pdf',
        'form-acroform.pdf',
        'scanned-letters-bundle.pdf', // no text layer: no blocks
      ]) {
        final blocks = await PdfStructure.extract(fixture(name));
        expect(
          blocks,
          name.startsWith('scanned') ? isEmpty : isNotEmpty,
          reason: name,
        );
      }
    });
  });
}
