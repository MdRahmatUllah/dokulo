import 'dart:io';

import 'package:doc_core/doc_core.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:test/test.dart';

/// The shared sample corpus (DK-0023), from the repo root.
String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

/// The AI text source (DK-0548).
void main() {
  setUpAll(pdfrxInitialize);

  group('chunk', () {
    test('never across a page; a heading starts a new chunk', () {
      final chunks = DocumentText.chunk([
        const Block(BlockKind.paragraph, 0, 'Eins.'),
        const Block(BlockKind.paragraph, 0, 'Zwei.'),
        const Block(BlockKind.heading, 0, '§ 2 Miete', level: 1),
        const Block(BlockKind.paragraph, 0, 'Drei.'),
        const Block(BlockKind.paragraph, 1, 'Vier.'),
      ]);
      expect(
        [for (final c in chunks) (c.page, c.text)],
        [(0, 'Eins.\n\nZwei.'), (0, '§ 2 Miete\n\nDrei.'), (1, 'Vier.')],
      );
    });

    test('a long block is cut at sentence ends, within the limit', () {
      final long = List.filled(30, 'Ein ganzer Satz hier.').join(' ');
      final chunks = DocumentText.chunk([
        Block(BlockKind.paragraph, 2, long),
      ], maxChars: 100);
      expect(chunks.length, greaterThan(5));
      for (final c in chunks) {
        expect(c.text.length, lessThanOrEqualTo(100));
        expect(c.text, endsWith('.'));
        expect(c.page, 2);
      }
      expect(chunks.map((c) => c.text).join(' '), long);
    });

    test('no text: no chunks, no text', () {
      expect(DocumentText(DocumentText.chunk(const [])).hasText, isFalse);
    });
  });

  test('a contract: chunks on every page, in reading order', () async {
    final text = await DocumentText.read(
      fixture('Mietvertrag Musterstraße 12.pdf'),
    );
    expect(text.hasText, isTrue);
    expect(text.pages, {0, 1, 2});
    expect(text.chunks.first.page, 0);
    expect(
      text.chunks.map((c) => c.page).toList(),
      orderedEquals([...text.chunks.map((c) => c.page)]..sort()),
    );
  });
}
