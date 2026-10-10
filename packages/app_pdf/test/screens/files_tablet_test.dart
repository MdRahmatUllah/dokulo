import 'package:app_pdf/components/dk_file_card.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/screens/files/file_preview_pane.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'files_screen_test.dart' show FilesFixture, pumpFiles, settle;

/// F1 on tablets (DK-0279; UI spec §30).
void main() {
  late FilesFixture f;
  setUp(() async {
    f = FilesFixture();
    await f.setUp();
  });
  tearDown(() => f.tearDown());

  Future<void> three(WidgetTester tester) => tester.runAsync(() async {
    await f.file('Mietvertrag.pdf', pages: 12, modified: DateTime(2026, 10, 3));
    await f.file('Invoice.pdf', modified: DateTime(2026, 10, 2));
    await f.file('Bescheid.pdf', modified: DateTime(2026, 10, 1));
  });

  /// The file the preview pane shows.
  String? previewed(WidgetTester tester) =>
      tester.widget<FilePreviewPane>(find.byType(FilePreviewPane)).file?.name;

  testWidgets('a large tablet: the list and the preview of the first file', (
    tester,
  ) async {
    await three(tester);
    await pumpFiles(tester, f, size: const Size(1366, 1024));
    expect(find.byType(FilePreviewPane), findsOneWidget);
    expect(previewed(tester), 'Mietvertrag.pdf');
    expect(find.text('Open'), findsOneWidget);
    // The quick tools, with the file.
    expect(find.text('Compress PDF'), findsOneWidget);
    expect(find.text('Black out (redact)'), findsOneWidget);
    // The list pane is 360 wide and a list: no grid toggle.
    expect(tester.getSize(find.byType(DkFileCard).first).width, 360);
    expect(find.byTooltip('Grid view'), findsNothing);
  });

  testWidgets('a tap selects: the preview follows, nothing navigates', (
    tester,
  ) async {
    await three(tester);
    final router = await pumpFiles(tester, f, size: const Size(1366, 1024));
    await tester.tap(find.text('Invoice.pdf').first);
    await settle(tester);
    expect(previewed(tester), 'Invoice.pdf');
    expect(router.state.uri.toString(), Routes.files);
  });

  testWidgets('the arrow keys move the selection', (tester) async {
    await three(tester);
    await pumpFiles(tester, f, size: const Size(1366, 1024));
    await tester.tap(find.text('Mietvertrag.pdf').first);
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    expect(previewed(tester), 'Invoice.pdf');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // stays last
    await settle(tester);
    expect(previewed(tester), 'Bescheid.pdf');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await settle(tester);
    expect(previewed(tester), 'Invoice.pdf');
  });

  testWidgets('a portrait tablet: one pane, the grid in 4 columns', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 6; i++) {
        await f.file('f$i.pdf');
      }
    });
    f.prefs['files.grid'] = true;
    await pumpFiles(tester, f, size: const Size(820, 1180));
    expect(find.byType(FilePreviewPane), findsNothing);
    final tops = {
      for (final e in find.byType(DkFileCard).evaluate())
        tester.getTopLeft(find.byWidget(e.widget)).dy,
    };
    final firstRow = find
        .byType(DkFileCard)
        .evaluate()
        .where(
          (e) => tester.getTopLeft(find.byWidget(e.widget)).dy == tops.first,
        );
    expect(firstRow, hasLength(4));
  });

  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('golden: two panes, $theme', (tester) async {
      await tester.runAsync(() async {
        for (final name in ['Taxes', 'Apartment', 'Work']) {
          await f.store.createFolder(f.db, name);
        }
      });
      await three(tester);
      await pumpFiles(tester, f, tokens: tokens, size: const Size(1366, 1024));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/files_tablet_landscape_$theme.png'),
      );
    });
  }

  testWidgets('a phone: unchanged, a tap opens the viewer', (tester) async {
    await three(tester);
    final router = await pumpFiles(tester, f);
    expect(find.byType(FilePreviewPane), findsNothing);
    await tester.tap(find.text('Invoice.pdf'));
    await settle(tester);
    expect(router.state.uri.toString(), startsWith('/viewer/'));
  });
}
