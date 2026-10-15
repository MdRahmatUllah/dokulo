import 'dart:io';

import 'package:app_pdf/components/dk_file_card.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/files_screen_test.dart' show FilesFixture, pumpFiles;

// Visual QA (DK-0751): the 04-files frame dragfolder, rendered by the real
// F1 in grid view at 393 × 852: a file held over a folder card (the ring,
// "Drop on “Apartment” to move"). The frame's screenshots are in
// docs/qa/folders/; the findings are in docs/qa/folders.md.
void main() {
  late FilesFixture f;
  setUp(() async {
    f = FilesFixture();
    await f.setUp();
  });
  tearDown(() => f.tearDown());

  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('files-dragfolder, $theme', (tester) async {
      await tester.runAsync(() async {
        for (final (name, tag) in [
          ('Taxes', 'blue'),
          ('Apartment', 'green'),
          ('Work', 'orange'),
          ('Receipts', 'grey'),
        ]) {
          final id = await f.store.createFolder(f.db, name);
          await (f.db.update(f.db.folders)..where((r) => r.id.equals(id)))
              .write(FoldersCompanion(colourTag: Value(tag)));
        }
        final pdf = File('${f.root.path}/Dokulo/Invoice INV-2026-014.pdf')
          ..createSync(recursive: true)
          ..writeAsStringSync('%PDF');
        await f.db
            .into(f.db.files)
            .insert(
              FilesCompanion.insert(
                path: pdf.path,
                name: 'Invoice INV-2026-014.pdf',
                size: 186000,
                created: DateTime(2026, 10, 1),
                modified: DateTime(2026, 10, 1),
              ),
            );
      });
      f.prefs['files.grid'] = true;
      await pumpFiles(tester, f, tokens: tokens);
      // The file into view, the folders still above it.
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -250),
      );
      await tester.pump(const Duration(milliseconds: 500));
      // As files_drag_test: the long press on the real clock, then over
      // Apartment and held there.
      late TestGesture g;
      await tester.runAsync(() async {
        g = await tester.startGesture(
          tester.getTopLeft(find.byType(DkFileCard)) + const Offset(60, 40),
        );
        await Future<void>.delayed(const Duration(milliseconds: 700));
        await tester.pump(const Duration(milliseconds: 700));
        await g.moveBy(const Offset(0, -8));
        await tester.pump();
        await g.moveTo(tester.getCenter(find.text('Apartment')));
        await tester.pump();
        await g.moveBy(const Offset(1, 1));
        await tester.pump();
      });
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/qa_folders_dragfolder_$theme.png'),
      );
      await tester.runAsync(() async {
        await g.cancel();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
