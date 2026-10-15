import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:test/test.dart';

/// The shared sample corpus (DK-0023), from the repo root.
String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

/// Smart Split's rules (DK-0552) and job (DK-0426).
void main() {
  setUpAll(pdfrxInitialize);

  PageSignals page({
    bool blank = false,
    double topInk = 0.02,
    int topHash = 0,
    String text = '',
  }) => PageSignals(blank: blank, topInk: topInk, topHash: topHash, text: text);

  List<List<int>> pagesOf(List<FoundDocument> docs) => [
    for (final d in docs) d.pages,
  ];

  group('rules', () {
    test('a blank sheet separates, and is left out', () {
      final docs = SmartSplitRules.split([page(), page(blank: true), page()]);
      expect(pagesOf(docs), [
        [0],
        [2],
      ]);
      expect(docs[1].reason, SplitReason.blankPage);
    });

    test('"Seite 1 von 3" starts a document', () {
      final docs = SmartSplitRules.split([
        page(text: 'Brief\nSeite 1 von 2'),
        page(text: 'Seite 2 von 2'),
        page(text: 'Rechnung\nPage 1 of 1'),
      ]);
      expect(pagesOf(docs), [
        [0, 1],
        [2],
      ]);
      expect(docs[1].reason, SplitReason.pageOneOf);
      expect(docs.map((d) => d.name), ['Brief', 'Rechnung']);
    });

    test(
      'another letterhead starts one; the same, or a bare top, does not',
      () {
        final docs = SmartSplitRules.split([
          page(topHash: 0x0F0F0F0F0F0F0F0F),
          page(topInk: 0.001, topHash: 0x7FFFFFFFFFFFFFFF), // no letterhead
          page(topHash: 0x0F0F0F0F0F0F0F0E), // the same, near enough
          page(topHash: 0x70F0F0F0F0F0F0F0), // another
        ]);
        expect(pagesOf(docs), [
          [0, 1, 2],
          [3],
        ]);
        expect(docs[1].reason, SplitReason.newLetterhead);
      },
    );

    test('a new date starts one', () {
      final docs = SmartSplitRules.split([
        page(text: 'München, 03.10.2026'),
        page(text: 'weiter'),
        page(text: 'Berlin, 12.09.2026'),
      ]);
      expect(pagesOf(docs), [
        [0, 1],
        [2],
      ]);
      expect(docs[1].reason, SplitReason.differentDate);
    });

    test('one document stays one; an empty bundle has none', () {
      expect(pagesOf(SmartSplitRules.split([page(), page(), page()])), [
        [0, 1, 2],
      ]);
      expect(SmartSplitRules.split([page(blank: true)]), isEmpty);
    });
  });

  test(
    'the scanned bundle: three letters (2 + 1 + 2 pages), the blank '
    'sheet left out, in under 20 s for its pages; the input untouched',
    () async {
      final dir = Directory.systemTemp.createTempSync('dk_smartsplit_');
      final db = DokuloDatabase.memory();
      addTearDown(() async {
        await db.close();
        dir.deleteSync(recursive: true);
      });
      final queue = JobQueue(
        IsolatePool(tempRoot: dir),
        db,
        ToolRegistry.app(),
      );
      final bundle = fixture('scanned-letters-bundle.pdf');
      final before = File(bundle).readAsBytesSync();
      final watch = Stopwatch()..start();
      final out =
          await (await queue.start(
                'smartsplit',
                SmartSplitInput(file: bundle),
              )).result
              as OneFile;
      watch.stop();
      final docs = (out.facts['documents']! as List)
          .cast<Map<String, Object?>>();
      expect(
        [for (final d in docs) d['pages']],
        [
          [0, 1],
          [2],
          [4, 5],
        ],
      );
      expect(docs.map((d) => d['reason']), [
        null,
        'newLetterhead',
        'blankPage',
      ]);
      expect(watch.elapsed, lessThan(const Duration(seconds: 20)));
      expect(File(bundle).readAsBytesSync(), before);
    },
  );
}
