import 'package:app_pdf/components/dk_bottom_bars.dart';
import 'package:app_pdf/components/dk_file_card.dart';
import 'package:app_pdf/components/dk_tab_bar.dart';
import 'package:app_pdf/providers/locked_providers.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'files_screen_test.dart' show FilesFixture, pumpFiles, settle;
import 'locked_folder_screen_test.dart' show LockedSetup;

/// F1's selection mode (DK-0263; UI spec §16.1).
void main() {
  late FilesFixture f;
  setUp(() async {
    f = FilesFixture();
    await f.setUp();
  });
  tearDown(() => f.tearDown());

  late List<int> ids;
  Future<void> three(WidgetTester tester) async {
    ids = (await tester.runAsync(
      () async => [
        await f.file('A.pdf', modified: DateTime(2026, 10, 3)),
        await f.file('B.pdf', modified: DateTime(2026, 10, 2)),
        await f.file('C.pdf', modified: DateTime(2026, 10, 1)),
      ],
    ))!;
  }

  DkBarAction action(WidgetTester tester, String label) => tester
      .widget<DkSelectionBar>(find.byType(DkSelectionBar))
      .actions
      .firstWhere((a) => a.label == label);

  testWidgets('a long press selects: "1 selected", the bar instead of the '
      'tabs; a tap toggles; Merge needs 2 PDFs', (tester) async {
    await three(tester);
    await pumpFiles(tester, f);
    await tester.longPress(find.text('A.pdf'));
    await settle(tester);
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byType(DkSelectionBar), findsOneWidget);
    expect(find.byType(DkTabBar), findsNothing);
    expect(action(tester, 'Merge').onPressed, isNull);
    expect(action(tester, 'Share').onPressed, isNull, reason: 'share_plus');

    await tester.tap(find.text('B.pdf'));
    await settle(tester);
    expect(find.text('2 selected'), findsOneWidget);
    expect(action(tester, 'Merge').onPressed, isNotNull);
    final checked = tester
        .widgetList<DkFileCard>(find.byType(DkFileCard))
        .where((c) => c.selected ?? false);
    expect(checked, hasLength(2));

    await tester.tap(find.text('Select all'));
    await settle(tester);
    expect(find.text('3 selected'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.byType(DkSelectionBar), findsNothing);
    expect(find.byType(DkTabBar), findsOneWidget);
  });

  testWidgets('Merge opens T2 with the files in the order they were picked', (
    tester,
  ) async {
    await three(tester);
    final router = await pumpFiles(tester, f);
    await tester.longPress(find.text('C.pdf'));
    await settle(tester);
    await tester.tap(find.text('A.pdf'));
    await settle(tester);
    await tester.tap(find.text('Merge'));
    await settle(tester);
    expect(
      router.state.uri.toString(),
      Routes.tool('merge', files: ['${ids[2]}', '${ids[0]}']),
    );
  });

  testWidgets('Select in the Files header; More → Delete moves them to '
      'Recently deleted', (tester) async {
    await three(tester);
    await pumpFiles(tester, f);
    await tester.tap(find.text('Select'));
    await settle(tester);
    expect(find.text('0 selected'), findsOneWidget);
    await tester.tap(find.text('A.pdf'));
    await tester.tap(find.text('B.pdf'));
    await settle(tester);
    await tester.tap(find.text('More'));
    await settle(tester);
    expect(find.text('Move to locked folder'), findsOneWidget);
    expect(find.text('Run a tool…'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    // Real files move to Recently deleted: real time for the disk.
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await settle(tester);
    }
    expect(find.text('Moved to Recently deleted'), findsOneWidget);
    expect(find.text('A.pdf'), findsNothing);
    expect(find.text('C.pdf'), findsOneWidget);
    expect(find.byType(DkSelectionBar), findsNothing);
  });

  testWidgets('Move to locked folder takes them to F2 (its setup first)', (
    tester,
  ) async {
    await three(tester);
    final router = await pumpFiles(
      tester,
      f,
      overrides: [lockedVaultProvider.overrideWithValue(LockedSetup().vault)],
    );
    await tester.longPress(find.text('A.pdf'));
    await settle(tester);
    await tester.tap(find.text('More'));
    await settle(tester);
    await tester.tap(find.text('Move to locked folder'));
    await settle(tester);
    expect(router.state.uri.toString(), Routes.lockedFolder);
    expect(router.state.extra, [ids[0]]);
  });

  testWidgets('More → Run a tool… opens X1 with the selected files', (
    tester,
  ) async {
    await three(tester);
    await pumpFiles(tester, f);
    await tester.longPress(find.text('A.pdf'));
    await settle(tester);
    await tester.tap(find.text('B.pdf'));
    await settle(tester);
    await tester.tap(find.text('More'));
    await settle(tester);
    await tester.tap(find.text('Run a tool…'));
    await settle(tester);
    expect(find.text('2 files'), findsOneWidget);
    expect(find.text('Merge PDF'), findsWidgets);
    expect(find.byType(DkSelectionBar), findsNothing);
  });

  testWidgets('back ends selection mode', (tester) async {
    await three(tester);
    await pumpFiles(tester, f);
    await tester.longPress(find.text('A.pdf'));
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(DkSelectionBar), findsNothing);
    expect(find.text('A.pdf'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  // Visual QA (DK-0736, DK-0752): the 04-files frames select and selmore,
  // the frame's folders and files with two selected. The frames'
  // screenshots are in docs/qa/files/; the findings in docs/qa/files-root.md.
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final frame in ['select', 'selmore']) {
      testWidgets('files-$frame, $theme', (tester) async {
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
          await f.file('Mietvertrag.pdf', modified: DateTime(2026, 10, 3));
          await f.file('Invoice.pdf', modified: DateTime(2026, 10, 2));
          await f.file('Scan.pdf', modified: DateTime(2026, 10, 1));
        });
        await pumpFiles(tester, f, tokens: tokens);
        await tester.longPress(find.text('Mietvertrag.pdf'));
        await settle(tester);
        await tester.tap(find.text('Invoice.pdf'));
        await settle(tester);
        if (frame == 'selmore') {
          await tester.tap(find.text('More'));
          await settle(tester);
        }
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../qa/goldens/qa_files_${frame}_$theme.png'),
        );
      });
    }
  }
}
