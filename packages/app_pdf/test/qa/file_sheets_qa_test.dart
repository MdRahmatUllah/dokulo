import 'dart:io';

import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/files_screen_test.dart'
    show FilesFixture, cardMore, pumpFiles, settle;

// Visual QA (DK-0742, DK-0743, DK-0744, DK-0745, DK-0747): the 04-files
// frames action, info, rename, move and trash, rendered by the real F1, its
// sheets and R1 at 393 × 852 with the frames' files. The goldens sit next to
// the frames' screenshots in docs/qa/file-sheets/; the findings are in
// docs/qa/file-sheets.md.
void main() {
  late FilesFixture f;
  setUp(() async {
    f = FilesFixture();
    await f.setUp();
  });
  tearDown(() => f.tearDown());

  /// Mietvertrag in Apartment's place at the root (the frames' file), a
  /// taken name for Rename, Taxes with 2025, 2026 and Belege for Move, and
  /// three in Recently deleted.
  Future<int> seed(WidgetTester tester) async =>
      (await tester.runAsync(() async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        File? file(String name) => File('${f.root.path}/Dokulo/$name')
          ..createSync(recursive: true)
          ..writeAsStringSync('%PDF-1.7\n');
        Future<int> row(String name, int size, int pages, DateTime at) {
          final path = file(name)!.path;
          return f.db
              .into(f.db.files)
              .insert(
                FilesCompanion.insert(
                  path: path,
                  name: name,
                  size: size,
                  pages: Value(pages),
                  created: DateTime(now.year, 10, 2, 9, 12),
                  modified: at,
                ),
              );
        }

        final id = await row(
          'Mietvertrag Musterstraße 12.pdf',
          2400000,
          12,
          today.add(const Duration(hours: 14, minutes: 32)),
        );
        await row('Taken.pdf', 1000, 1, today);
        final taxes = await f.store.createFolder(f.db, 'Taxes');
        for (final name in ['2025', '2026', 'Belege']) {
          await f.store.createFolder(f.db, name, parent: taxes);
        }
        for (final (name, size, days) in [
          ('Scan 2026-09-30 08.12.pdf', 1200000, 2),
          ('Invoice INV-2026-009.pdf', 160000, 9),
          ('Draft cover letter.pdf', 88000, 26),
        ]) {
          final t = await row(name, size, 1, today);
          await f.store.trashFile(
            f.db,
            t,
            now: now.subtract(Duration(days: days)),
          );
        }
        return id;
      }))!;

  Future<void> realTap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    for (var i = 0; i < 3; i++) {
      await settle(tester);
    }
  }

  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    Future<void> shot(WidgetTester tester, String frame) => expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/qa_file_sheets_${frame}_$theme.png'),
    );

    testWidgets('files-action, $theme', (tester) async {
      await seed(tester);
      await pumpFiles(tester, f, tokens: tokens);
      await realTap(tester, cardMore);
      await shot(tester, 'action');
    });

    testWidgets('files-info, $theme', (tester) async {
      await seed(tester);
      await pumpFiles(tester, f, tokens: tokens);
      await realTap(tester, cardMore);
      await realTap(tester, find.text('Info'));
      await shot(tester, 'info');
    });

    testWidgets('files-rename (error), $theme', (tester) async {
      await seed(tester);
      await pumpFiles(tester, f, tokens: tokens);
      await realTap(tester, cardMore);
      await realTap(tester, find.text('Rename'));
      await tester.enterText(find.byType(EditableText).last, 'Taken');
      await tester.pump();
      await realTap(tester, find.text('Rename').last);
      await shot(tester, 'rename');
    });

    testWidgets('files-move, $theme', (tester) async {
      await seed(tester);
      await pumpFiles(tester, f, tokens: tokens);
      await realTap(tester, cardMore);
      await realTap(tester, find.text('Move'));
      await realTap(tester, find.text('Taxes').last);
      await shot(tester, 'move');
    });

    testWidgets('files-trash, $theme', (tester) async {
      await seed(tester);
      await pumpFiles(tester, f, tokens: tokens, location: Routes.trash);
      await shot(tester, 'trash');
    });
  }
}
