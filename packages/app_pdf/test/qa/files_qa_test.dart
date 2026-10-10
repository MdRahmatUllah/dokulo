import 'dart:async';

import 'package:app_pdf/providers/files_providers.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/files_screen_test.dart' show FilesFixture, pumpFiles, settle;

// Visual QA (DK-0733, DK-0734, DK-0737, DK-0741, DK-0749): the 04-files
// root frames list, grid, empty, sort and loading, rendered by the real F1
// in the shell at 393 × 852 with the frames' folders and files. The goldens
// sit next to the frames' screenshots in docs/qa/files/; the findings are in
// docs/qa/files-root.md.

/// The frames' library: four tagged folders with their counts, three files
/// at the root (today), three in Recently deleted.
Future<void> seedFrames(WidgetTester tester, FilesFixture f) =>
    tester.runAsync(() async {
      final db = f.db;
      for (final (name, tag, count) in [
        ('Taxes', 'blue', 8),
        ('Apartment', 'green', 5),
        ('Work', 'orange', 12),
        ('Receipts', 'grey', 23),
      ]) {
        final folder = await f.folder(name, tag: tag);
        for (var i = 0; i < count; i++) {
          await f.file('$name $i.pdf', folder: folder);
        }
      }
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      for (final (name, size, pages, minutes) in [
        ('Mietvertrag Musterstraße 12.pdf', 2400000, 12, 14 * 60 + 32),
        ('Invoice INV-2026-014.pdf', 186000, 2, 9 * 60 + 5),
        ('Personalausweis – scan.pdf', 1100000, 2, 8 * 60),
      ]) {
        await f.file(
          name,
          size: size,
          pages: pages,
          modified: today.add(Duration(minutes: minutes)),
        );
      }
      for (var i = 0; i < 3; i++) {
        final id = await f.file('Deleted $i.pdf');
        await db
            .into(db.trash)
            .insert(TrashCompanion.insert(fileId: Value(id), deletedAt: now));
      }
    });

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
    Future<void> shot(WidgetTester tester, String frame) => expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/qa_files_${frame}_$theme.png'),
    );

    testWidgets('files-list, $theme', (tester) async {
      await seedFrames(tester, f);
      await pumpFiles(tester, f, tokens: tokens);
      await shot(tester, 'list');
    });

    testWidgets('files-grid, $theme', (tester) async {
      await seedFrames(tester, f);
      f.prefs['files.grid'] = true;
      await pumpFiles(tester, f, tokens: tokens);
      await shot(tester, 'grid');
    });

    testWidgets('files-empty, $theme', (tester) async {
      await pumpFiles(tester, f, tokens: tokens);
      await shot(tester, 'empty');
    });

    testWidgets('files-sort, $theme', (tester) async {
      await seedFrames(tester, f);
      await pumpFiles(tester, f, tokens: tokens);
      await tester.tap(find.byTooltip('Sort'));
      await settle(tester);
      await shot(tester, 'sort');
    });

    testWidgets('files-loading, $theme', (tester) async {
      // Folders and files still on their way: the skeleton.
      final never = StreamController<Never>();
      addTearDown(never.close);
      await pumpFiles(
        tester,
        f,
        tokens: tokens,
        settled: false,
        overrides: [
          foldersProvider(null).overrideWith((ref) => never.stream),
          filesInProvider(null).overrideWith((ref) => never.stream),
        ],
      );
      await tester.pump(const Duration(milliseconds: 300));
      await shot(tester, 'loading');
    });
  }
}
