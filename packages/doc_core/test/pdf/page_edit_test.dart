import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:doc_core/doc_core.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' show pdfrxInitialize;
import 'package:test/test.dart';

/// The shared sample corpus (DK-0023), from the repo root.
String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

/// Organize pages' engine (DK-0330): each operation, checked on the file it
/// writes (page order by each page's unique word, sizes, rotation).
void main() {
  late Directory dir;
  late String five; // pages Abschnitt001…005 of the long fixture
  final sep = Platform.pathSeparator;

  setUpAll(() async {
    pdfrxInitialize();
    dir = await Directory.systemTemp.createTemp('dk_pages_');
    five = '${dir.path}${sep}five.pdf';
    await PdfEngine.assemble([
      for (var i = 0; i < 5; i++) PageSource(fixture('long-300-pages.pdf'), i),
    ], five);
  });
  tearDownAll(() => dir.delete(recursive: true));

  var n = 0;
  Future<String> saved(PageEdit edit) async {
    final out = '${dir.path}${sep}out${n++}.pdf';
    await edit.save(out);
    return out;
  }

  /// The sections of [path]'s pages in order: "1" for Abschnitt001; "-" for
  /// a page without one (blank, another document).
  Future<List<String>> order(String path) async {
    final info = await PdfEngine.inspect(path);
    return [
      for (var i = 0; i < info.pageCount; i++)
        switch (RegExp(r'Abschnitt(\d{3})')
            .firstMatch((await PdfEngine.pageText(path, i)).text)) {
          final m? => '${int.parse(m.group(1)!)}',
          null => '-',
        },
    ];
  }

  test('move one page, and several together', () async {
    final edit = PageEdit(five, 5)..move(0, 3);
    expect(await order(await saved(edit)), ['2', '3', '4', '1', '5']);
    final many = PageEdit(five, 5)..moveAll({0, 1}, 2);
    expect(await order(await saved(many)), ['3', '4', '1', '2', '5']);
  });

  test('delete; a PDF keeps one page', () async {
    final edit = PageEdit(five, 5)..delete({1, 3});
    expect(await order(await saved(edit)), ['1', '3', '5']);
    expect(
      () => PageEdit(five, 5).delete({0, 1, 2, 3, 4}),
      throwsArgumentError,
    );
  });

  test('duplicate puts the copy right after', () async {
    final edit = PageEdit(five, 5)..duplicate({0, 4});
    expect(await order(await saved(edit)), ['1', '1', '2', '3', '4', '5', '5']);
  });

  test('rotate turns the page: width and height swap', () async {
    final before = (await PdfEngine.inspect(five)).pages.first;
    final edit = PageEdit(five, 5)..rotate({0}, 1);
    final after = (await PdfEngine.inspect(await saved(edit))).pages;
    expect(after[0].quarterTurns, (before.quarterTurns + 1) % 4);
    expect(after[0].width, closeTo(before.height, 0.5));
    expect(after[1].width, closeTo(before.width, 0.5), reason: 'not turned');
    final back = PageEdit(five, 5)
      ..rotate({0}, 1)
      ..rotate({0}, -1);
    expect(back.pages.first.addQuarterTurns, 0);
  });

  test('insert pages from another file, and a blank one the size of its '
      'neighbour', () async {
    final edit = PageEdit(five, 5)
      ..insert(1, [PageSource(fixture('Invoice INV-2026-014.pdf'), 0)]);
    await edit.insertBlank(3, dir);
    final out = await saved(edit);
    expect(await order(out), ['1', '-', '2', '-', '3', '4', '5']);
    expect((await PdfEngine.pageText(out, 1)).text, contains('INV-2026-014'));
    final pages = (await PdfEngine.inspect(out)).pages;
    expect(pages[3].width, closeTo(pages[2].width, 0.5));
    expect(pages[3].height, closeTo(pages[2].height, 0.5));
    expect((await PdfEngine.pageText(out, 3)).text.trim(), isEmpty);
  });

  test('undo and redo step through the edits; changed only after one', () {
    final edit = PageEdit(five, 5);
    expect(edit.changed, isFalse);
    edit
      ..delete({0})
      ..move(0, 1);
    expect(edit.pages.map((p) => p.page), [2, 1, 3, 4]);
    edit.undo();
    expect(edit.pages.map((p) => p.page), [1, 2, 3, 4]);
    edit.undo();
    expect(edit.pages.map((p) => p.page), [0, 1, 2, 3, 4]);
    expect(edit.canUndo, isFalse);
    edit.redo();
    expect(edit.pages.map((p) => p.page), [1, 2, 3, 4]);
    edit.rotate({0}, 1);
    expect(edit.canRedo, isFalse, reason: 'a new edit drops the redo');
  });

  test('saving as a copy leaves the original untouched (by hash)', () async {
    Future<String> hash(String p) async =>
        sha256.convert(await File(p).readAsBytes()).toString();
    final before = await hash(five);
    final edit = PageEdit(five, 5)
      ..delete({2})
      ..rotate({0}, 2);
    await saved(edit);
    expect(await hash(five), before);
  });
}
