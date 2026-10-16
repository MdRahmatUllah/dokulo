import 'dart:io';

import 'package:app_pdf/components/dk_editor_bars.dart';
import 'package:app_pdf/components/dk_pdf_canvas.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/providers/file_providers.dart';
import 'package:app_pdf/providers/files_providers.dart';
import 'package:app_pdf/providers/prefs_providers.dart';
import 'package:app_pdf/screens/v1_viewer/viewer_screen.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import '../viewer_screen_test.dart' show app, fixture, settle;

void main() {
  const yellow = Color(0xFFFFEB3B);
  final selected = <SelectionLines>[
    (
      page: 0,
      lines: [
        (
          box: (left: 70, top: 700, right: 300, bottom: 688),
          dir: LineDir.right,
        ),
        (
          box: (left: 70, top: 686, right: 180, bottom: 674),
          dir: LineDir.right,
        ),
      ],
    ),
    (
      page: 1,
      lines: [
        (
          box: (left: 70, top: 760, right: 120, bottom: 748),
          dir: LineDir.right,
        ),
      ],
    ),
    (page: 2, lines: []),
  ];

  test('one markup per page, a quad per line, in the PDF corner order', () {
    final edits = markupEdits(DkMarkupAction.highlight, selected, yellow);
    expect(edits.keys, [0, 1], reason: 'a page with no lines is left alone');
    final m = edits[0]!.add.single as MarkupAnnot;
    expect(m.kind, MarkupKind.highlight);
    expect(m.quads, hasLength(2));
    expect(m.quads.first, (
      (x: 70.0, y: 700.0),
      (x: 300.0, y: 700.0),
      (x: 70.0, y: 688.0),
      (x: 300.0, y: 688.0),
    ));
  });

  test('sideways and upside-down lines: the quad turns with the text, so '
      'the underline (lower left to lower right) runs under the letters '
      '(DK-1138)', () {
    const box = (left: 100.0, top: 400.0, right: 112.0, bottom: 200.0);
    MarkupQuad quad(LineDir dir) =>
        (markupEdits(DkMarkupAction.underline, [
                  (page: 0, lines: [(box: box, dir: dir)]),
                ], yellow)[0]!.add.single
                as MarkupAnnot)
            .quads
            .single;
    // Reading up the page, the letters' feet are on the right.
    expect(quad(LineDir.up), (
      (x: 100.0, y: 200.0),
      (x: 100.0, y: 400.0),
      (x: 112.0, y: 200.0),
      (x: 112.0, y: 400.0),
    ));
    // Reading down, on the left.
    expect(quad(LineDir.down), (
      (x: 112.0, y: 400.0),
      (x: 112.0, y: 200.0),
      (x: 100.0, y: 400.0),
      (x: 100.0, y: 200.0),
    ));
    // Upside down, along the top.
    expect(quad(LineDir.left), (
      (x: 112.0, y: 200.0),
      (x: 100.0, y: 200.0),
      (x: 112.0, y: 400.0),
      (x: 100.0, y: 400.0),
    ));
  });

  test('a highlight is see-through; underline and strike are opaque', () {
    int alpha(DkMarkupAction a) =>
        (markupEdits(a, selected, yellow)[0]!.add.single.color >> 24) & 0xFF;
    expect(alpha(DkMarkupAction.highlight), closeTo(0.4 * 255, 1));
    expect(alpha(DkMarkupAction.underline), 255);
    expect(
      (markupEdits(DkMarkupAction.strike, selected, yellow)[0]!.add.single
              as MarkupAnnot)
          .kind,
      MarkupKind.strikeOut,
    );
  });

  test('Copy and Ask make no annotation', () {
    expect(markupEdits(DkMarkupAction.copy, selected, yellow), isEmpty);
    expect(markupEdits(DkMarkupAction.ask, selected, yellow), isEmpty);
  });

  group('select → Highlight → Undo (DK-1138)', () {
    setUpAll(pdfrxInitialize);
    late Directory root;
    late DokuloDatabase db;

    setUp(() {
      root = Directory.systemTemp.createTempSync('dk_v1_markup_');
      db = DokuloDatabase.memory();
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1;
    });
    tearDown(() async {
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset();
      await db.close();
      try {
        root.deleteSync(recursive: true);
      } on FileSystemException {
        // PDFium may still hold the file on Windows: the OS cleans temp.
      }
    });

    testWidgets('on a /Rotate 90 page: the highlight goes into the file, the '
        'canvas opens it again, Undo takes it out', (tester) async {
      final store = FileStore(
        userFolder: Directory('${root.path}/Dokulo'),
        workDirectory: Directory('${root.path}/work'),
      );
      final versions = _OpenFileVersions(db, Directory('${root.path}/v'));
      final (id, path) = (await tester.runAsync(() async {
        Directory('${root.path}/Dokulo').createSync(recursive: true);
        final copy = await File(fixture('corpus/rotated-pages.pdf'))
            .copy('${root.path}/Dokulo/Rotated.pdf');
        final id = await db
            .into(db.files)
            .insert(
              FilesCompanion.insert(
                path: copy.path,
                name: 'Rotated.pdf',
                size: 1,
                created: DateTime(2026),
                modified: DateTime(2026),
              ),
            );
        return (id, copy.path);
      }))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            fileStoreProvider.overrideWith((ref) async => store),
            prefsProvider.overrideWith(() => Prefs.memory({})),
            versionStoreProvider.overrideWith((ref) async => versions),
          ],
          child: app(ViewerScreen(fileId: id)),
        ),
      );
      await settle(tester);

      // What pdfrx's selection of page 2's heading gives the canvas.
      final lines = (await tester.runAsync(() async {
        final text = await PdfEngine.pageText(path, 1);
        return PdfRedactor.lineRuns(
          text.charBoxes,
          0,
          text.text.indexOf(' (Rotate'),
        );
      }))!;
      Future<List<PageAnnot>> annots(String file) async =>
          (await tester.runAsync(() => PdfAnnotations.read(file, 1)))!;
      expect(await annots(path), isEmpty);
      int revision() =>
          tester.widget<DkPdfCanvas>(find.byType(DkPdfCanvas)).revision;
      final before = revision();

      tester.widget<DkPdfCanvas>(find.byType(DkPdfCanvas)).onMarkup!(
        DkMarkupAction.highlight,
        [(page: 1, lines: lines)],
      );
      await settle(tester);
      final marked = await annots(versions.replacedWith!);
      final m = marked.single.annot as MarkupAnnot;
      expect(m.kind, MarkupKind.highlight);
      // The heading runs across the unrotated page: one quad, upright order.
      final b = lines.single.box;
      expect(m.quads.single.$1.x, closeTo(b.left, 1));
      expect(m.quads.single.$1.y, closeTo(b.top, 1));
      expect(revision(), before + 1, reason: 'the canvas re-opens the file');

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(versions.restored, isNotNull, reason: 'the kept version is back');
      expect(revision(), before + 2);
    });
  });
}

/// The version store, but the file is not overwritten: Windows refuses to
/// replace a file PDFium holds open (Android's copy goes through a rename),
/// so what would replace it is kept beside it.
class _OpenFileVersions extends VersionStore {
  _OpenFileVersions(super.db, super.directory);

  String? replacedWith;
  Version? restored;

  @override
  Future<Version> replace(int fileId, String source) async {
    replacedWith = (await File(source).copy('$source.kept')).path;
    return save(fileId);
  }

  @override
  Future<void> restore(Version version) async => restored = version;
}
