import 'dart:io';

import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/files_screen_test.dart' show FilesFixture, pumpFiles, settle;

// Visual QA (DK-0735, DK-0738, DK-0746, DK-0754): the 04-files frames
// folder, emptyfolder, newfolder and foldermenu,
// rendered by the real F1 and its folder screen at 393 × 852 with the
// frames' folders and files. The goldens sit next to the frames'
// screenshots in docs/qa/folders/; the findings are in docs/qa/folders.md.
void main() {
  late FilesFixture f;
  setUp(() async {
    f = FilesFixture();
    await f.setUp();
  });
  tearDown(() => f.tearDown());

  /// Taxes › 2026 with the frame's four files; Apartment, Work, Receipts at
  /// the root; Invoice at the root for the drag.
  Future<(int, int)> seed(WidgetTester tester) async =>
      (await tester.runAsync(() async {
        final taxes = await f.store.createFolder(f.db, 'Taxes');
        final year = await f.store.createFolder(f.db, '2026', parent: taxes);
        await (f.db.update(f.db.folders)..where((r) => r.id.equals(taxes)))
            .write(const FoldersCompanion(colourTag: Value('blue')));
        for (final (name, tag) in [
          ('Apartment', 'green'),
          ('Work', 'orange'),
          ('Receipts', 'grey'),
        ]) {
          final id = await f.store.createFolder(f.db, name);
          await (f.db.update(f.db.folders)..where((r) => r.id.equals(id)))
              .write(FoldersCompanion(colourTag: Value(tag)));
        }
        final now = DateTime.now();
        for (final (name, size, pages, at) in [
          (
            'Finanzamt München – Bescheid 2025.pdf',
            640000,
            4,
            now.subtract(const Duration(days: 1)),
          ),
          (
            'Lohnsteuerbescheinigung 2025.pdf',
            220000,
            1,
            DateTime(now.year, 10, 2),
          ),
          ('Spendenquittung.pdf', 98000, 1, DateTime(now.year, 9, 28)),
          ('Nebenkostenabrechnung.pdf', 1400000, 3, DateTime(now.year, 9, 21)),
        ]) {
          await f.file(
            name,
            size: size,
            pages: pages,
            modified: at,
            folder: year,
          );
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
                pages: const Value(2),
                created: now,
                modified: now,
              ),
            );
        return (taxes, year);
      }))!;

  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    Future<void> shot(WidgetTester tester, String frame) => expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/qa_folders_${frame}_$theme.png'),
    );

    testWidgets('files-folder, $theme', (tester) async {
      final (_, year) = await seed(tester);
      await pumpFiles(tester, f, tokens: tokens, location: Routes.folder(year));
      await shot(tester, 'folder');
    });

    testWidgets('files-foldermenu, $theme', (tester) async {
      final (_, year) = await seed(tester);
      await pumpFiles(tester, f, tokens: tokens, location: Routes.folder(year));
      await tester.tap(find.byTooltip('More'));
      await settle(tester);
      await shot(tester, 'foldermenu');
    });

    testWidgets('files-emptyfolder, $theme', (tester) async {
      final empty = (await tester.runAsync(
        () => f.store.createFolder(f.db, 'Taxes'),
      ))!;
      await pumpFiles(
        tester,
        f,
        tokens: tokens,
        location: Routes.folder(empty),
      );
      await shot(tester, 'emptyfolder');
    });

    testWidgets('files-newfolder, $theme', (tester) async {
      await seed(tester);
      await pumpFiles(tester, f, tokens: tokens);
      await tester.tap(find.byTooltip('New folder'));
      await settle(tester);
      await shot(tester, 'newfolder');
    });
  }
}
