import 'package:app_pdf/components/dk_file_card.dart';
import 'package:app_pdf/patterns/dk_swipe_actions.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'files_screen_test.dart' show FilesFixture, pumpFiles, settle;

/// A Files row swiped left (DK-0268; UI spec §12.3).
void main() {
  late FilesFixture f;
  setUp(() async {
    f = FilesFixture();
    await f.setUp();
  });
  tearDown(() => f.tearDown());

  Future<void> one(WidgetTester tester) =>
      tester.runAsync(() => f.file('Invoice.pdf'));

  testWidgets('a short swipe opens Share and Delete; Share waits for '
      'share_plus', (tester) async {
    await one(tester);
    await pumpFiles(tester, f);
    expect(find.byType(DkSwipeActions), findsOneWidget);
    await tester.drag(find.text('Invoice.pdf'), const Offset(-140, 0));
    await settle(tester);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    final share = tester.widget<InkWell>(
      find.ancestor(of: find.text('Share'), matching: find.byType(InkWell)),
    );
    expect(share.onTap, isNull);
  });

  testWidgets('a full swipe deletes, with Undo', (tester) async {
    await one(tester);
    await pumpFiles(tester, f);
    await tester.runAsync(() async {
      await tester.drag(find.text('Invoice.pdf'), const Offset(-380, 0));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    for (var i = 0; i < 3; i++) {
      await settle(tester);
    }
    expect(find.text('Moved to Recently deleted'), findsOneWidget);
    expect(find.text('Invoice.pdf'), findsNothing);
    await tester.runAsync(() async {
      await tester.tap(find.text('Undo'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    for (var i = 0; i < 3; i++) {
      await settle(tester);
    }
    expect(find.text('Invoice.pdf'), findsOneWidget);
  });

  // Visual QA (DK-0750): the 04-files frame swipe, the frame's files with
  // Mietvertrag swiped open. The frame's screenshots are in
  // docs/qa/files/; the findings are in docs/qa/files-root.md.
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('files-swipe, $theme', (tester) async {
      await tester.runAsync(() async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
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
        for (final (name, size, pages, at) in [
          (
            'Mietvertrag Musterstraße 12.pdf',
            2400000,
            12,
            today.add(const Duration(hours: 14, minutes: 32)),
          ),
          (
            'Invoice INV-2026-014.pdf',
            186000,
            2,
            today.add(const Duration(hours: 9, minutes: 5)),
          ),
          (
            'Personalausweis – scan.pdf',
            1100000,
            2,
            today.subtract(const Duration(hours: 6)),
          ),
        ]) {
          await f.file(name, size: size, pages: pages, modified: at);
        }
      });
      await pumpFiles(tester, f, tokens: tokens);
      // The row near its top: its middle is under the tab bar.
      await tester.dragFrom(
        tester.getTopLeft(find.byType(DkFileCard).first) +
            const Offset(200, 20),
        const Offset(-170, 0),
      );
      await settle(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../qa/goldens/qa_files_swipe_$theme.png'),
      );
    });
  }
}
