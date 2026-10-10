import 'package:app_pdf/components/dk_file_card.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/files_screen_test.dart' show FilesFixture, pumpFiles, settle;

// Visual QA (DK-0739, DK-0740, DK-0748, DK-0753): the 04-files frames
// search, searchempty, emptytrash and trashaction, rendered by the real F1
// and R1 at 393 × 852 with the frames' files. The frames' screenshots are in
// docs/qa/search-trash/; the findings are in docs/qa/search-trash.md.
void main() {
  late FilesFixture f;
  setUp(() async {
    f = FilesFixture();
    await f.setUp();
  });
  tearDown(() => f.tearDown());

  /// Mietvertrag by name; Finanzamt and a scan with the word inside;
  /// Mietvertrag and the trashed files have no text layer; three files in
  /// Recently deleted.
  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
    final db = f.db;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await f.file(
      'Mietvertrag Musterstraße 12.pdf',
      size: 2400000,
      pages: 12,
      modified: today.add(const Duration(hours: 14, minutes: 32)),
    );
    for (final (name, size, pages, page, text) in [
      (
        'Finanzamt München – Bescheid 2025.pdf',
        640000,
        4,
        2,
        'Aufwendungen laut Mietvertrag vom 1. März 2024 werden anerkannt',
      ),
      (
        'Scan 2026-09-12 10.14.pdf',
        3600000,
        3,
        1,
        'Kündigung des Mietvertrags mit einer Frist von drei Monaten',
      ),
    ]) {
      final id = await f.file(name, size: size, pages: pages);
      await db.customInsert(
        'INSERT INTO ocr_text (file_id, page, page_text) VALUES (?, ?, ?)',
        variables: [Variable(id), Variable(page), Variable(text)],
      );
      await (db.update(db.files)..where((r) => r.id.equals(id))).write(
        const FilesCompanion(hasText: Value(true)),
      );
    }
    for (final (name, days) in [
      ('Scan 2026-09-30 08.12.pdf', 2),
      ('Invoice INV-2026-009.pdf', 9),
      ('Draft cover letter.pdf', 26),
    ]) {
      final id = await f.file(name, size: 160000, pages: 1);
      await f.store.trashFile(db, id, now: now.subtract(Duration(days: days)));
    }
  });

  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    Future<void> shot(WidgetTester tester, String frame) => expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/qa_search_trash_${frame}_$theme.png'),
    );

    testWidgets('files-search ("Mietvertrag"), $theme', (tester) async {
      await seed(tester);
      await pumpFiles(tester, f, tokens: tokens);
      await tester.enterText(find.byType(EditableText).first, 'Mietvertrag');
      for (var i = 0; i < 3; i++) {
        await settle(tester);
      }
      await shot(tester, 'search');
    });

    testWidgets('files-searchempty ("Kaution"), $theme', (tester) async {
      await seed(tester);
      await pumpFiles(tester, f, tokens: tokens);
      await tester.enterText(find.byType(EditableText).first, 'Kaution');
      for (var i = 0; i < 3; i++) {
        await settle(tester);
      }
      await shot(tester, 'searchempty');
    });

    testWidgets('files-trashaction, $theme', (tester) async {
      await seed(tester);
      await pumpFiles(tester, f, tokens: tokens, location: Routes.trash);
      for (var i = 0; i < 3; i++) {
        await settle(tester);
      }
      await tester.tap(find.byType(DkFileCard).first);
      await settle(tester);
      await shot(tester, 'trashaction');
    });

    testWidgets('files-emptytrash, $theme', (tester) async {
      await seed(tester);
      await pumpFiles(tester, f, tokens: tokens, location: Routes.trash);
      for (var i = 0; i < 3; i++) {
        await settle(tester);
      }
      await tester.tap(find.text('Empty'));
      await settle(tester);
      await shot(tester, 'emptytrash');
    });
  }
}
