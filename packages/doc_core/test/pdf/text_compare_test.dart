import 'dart:io';

import 'package:doc_core/doc_core.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:test/test.dart';

/// A PDF with one page per string (Helvetica, so PDFium reads it back).
Future<String> pdf(Directory dir, String name, List<String> pages) async {
  final doc = pw.Document();
  for (final text in pages) {
    doc.addPage(pw.Page(build: (_) => pw.Text(text)));
  }
  final path = '${dir.path}/$name';
  await File(path).writeAsBytes(await doc.save());
  return path;
}

void main() {
  setUpAll(pdfrxInitialize);

  test('the word diff: changed, added, removed, unchanged', () {
    PageText t(String s) => PageText(
      text: s,
      charBoxes: [
        for (var i = 0; i < s.length; i++)
          (left: i * 5.0, top: 700.0, right: i * 5.0 + 5, bottom: 688.0),
      ],
    );
    final changes = PdfCompare.pageChanges(
      0,
      t('The rent is 900 EUR per month. Payment by the third day.'),
      t(
        'The rent is 950 EUR per month. Payment by the fifth working day. '
        'Pets allowed.',
      ),
    );
    expect(
      [for (final c in changes) (c.kind, c.before, c.after)],
      [
        (ChangeKind.changed, '900', '950'),
        (ChangeKind.changed, 'third', 'fifth working'),
        (ChangeKind.added, '', 'Pets allowed.'),
      ],
    );
    expect(changes.first.oldBoxes.single.left, 60);
    expect(changes.last.oldBoxes, isEmpty);
    expect(
      PdfCompare.pageChanges(1, t('Same text.'), t('Same text.')),
      isEmpty,
    );
  });

  test('a fixture pair: counts per kind, a page only the newer has', () async {
    final dir = await Directory.systemTemp.createTemp('dk_cmp_');
    addTearDown(() => dir.delete(recursive: true));
    final older = await pdf(dir, 'v1.pdf', [
      'Mietvertrag. Die Miete betraegt 900 EUR. Kaution 2700 EUR.',
    ]);
    final newer = await pdf(dir, 'v2.pdf', [
      'Mietvertrag. Die Miete betraegt 950 EUR. Haustiere erlaubt.',
      'Anlage: Hausordnung',
    ]);
    final changes = await PdfCompare.text(older, newer);
    expect(PdfCompare.counts(changes), {
      ChangeKind.added: 1,
      ChangeKind.removed: 0,
      ChangeKind.changed: 2,
    });
    final added = changes.singleWhere((c) => c.kind == ChangeKind.added);
    expect((added.newPage, added.after), (1, 'Anlage: Hausordnung'));
    expect(added.newBoxes, isNotEmpty, reason: 'highlightable');
  });
}
