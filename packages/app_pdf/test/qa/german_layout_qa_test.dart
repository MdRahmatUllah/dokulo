import 'dart:io';

import 'package:app_pdf/components/dk_button.dart';
import 'package:app_pdf/components/dk_chip.dart';
import 'package:app_pdf/components/dk_next_chip.dart';
import 'package:app_pdf/components/dk_segmented.dart';
import 'package:app_pdf/components/dk_text_action.dart';
import 'package:app_pdf/components/dk_tool_tile.dart';
import 'package:app_pdf/providers/file_providers.dart';
import 'package:app_pdf/providers/locked_providers.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import '../routes/routes_test.dart' show pumpAt;
import '../screens/locked_folder_screen_test.dart' show LockedSetup;

/// German layout QA (DK-0635): German runs about 30 % longer than English.
/// Every DE-marked screen the router reaches, in German at 100 % text on the
/// phone frame and at 200 % on the smallest one (iPhone SE): nothing
/// overflows (an overflow is an exception in a test) and no button, chip,
/// segment or tool name is cut: they wrap instead (UI spec §27, §28).
/// The board draws with Roboto (the SDK's copy, what Android shows), not
/// the test font: Ahem's square glyphs make every German word far too wide
/// to judge a line break. Findings: docs/qa/german-layout.md.
void main() {
  setUpAll(pdfrxInitialize); // V1, V2 and P1 render the sample
  setUpAll(() async {
    final fonts = Directory(
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts',
    );
    final roboto = FontLoader('Roboto');
    for (final w in ['regular', 'medium', 'bold']) {
      final bytes = File('${fonts.path}/roboto-$w.ttf').readAsBytesSync();
      roboto.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await roboto.load();
  });

  final screens = [
    Routes.welcome,
    Routes.home,
    Routes.tools,
    Routes.files,
    Routes.trash,
    Routes.lockedFolder,
    Routes.me,
    Routes.models,
    Routes.signatures,
    for (final page in [
      'scanning',
      'security',
      'files',
      'language',
      'appearance',
    ])
      Routes.settings(page),
    Routes.scan,
    Routes.photos,
    for (final tool in ['compress', 'img2pdf', 'merge', 'redact', 'ocr'])
      Routes.tool(tool),
  ];

  /// V1, V2 and P1 on the invoice sample (row 1 of the database).
  final fileScreens = [
    Routes.viewer('1'),
    Routes.viewer('1', edit: true),
    Routes.organize('1'),
  ];

  /// The controls' texts that don't fit: past their line limit, or wider
  /// than their box on a line that can't wrap.
  List<String> cut(WidgetTester tester) => [
    for (final type in [
      DkButton,
      DkChip,
      DkNextChip,
      DkSegmented,
      DkTextAction,
      DkToolTile,
      DkToolRow,
    ])
      for (final e
          in find
              .descendant(
                of: find.byType(type),
                matching: find.byType(RichText),
              )
              .evaluate())
        if (_cut(e.renderObject! as RenderParagraph) &&
            !_frameCuts.contains((e.widget as RichText).text.toPlainText()))
          (e.widget as RichText).text.toPlainText(),
  ];

  for (final (size, scale) in [
    (const Size(393, 852), 1.0),
    (const Size(375, 667), 2.0),
  ]) {
    for (final location in [...screens, ...fileScreens]) {
      testWidgets('$location in German at ${(scale * 100).round()} %', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final root = Directory.systemTemp.createTempSync('dk_de_');
        addTearDown(() => root.deleteSync(recursive: true));
        final db = DokuloDatabase.memory();
        addTearDown(db.close);
        final store = FileStore(
          userFolder: Directory('${root.path}/Dokulo'),
          workDirectory: Directory('${root.path}/work'),
        );
        if (fileScreens.contains(location)) {
          await tester.runAsync(() async {
            store.userFolder.createSync(recursive: true);
            final pdf = await File(
              '${Directory.current.path}/../../test/fixtures/'
              'Invoice INV-2026-014.pdf',
            ).copy('${store.userFolder.path}/Rechnung.pdf');
            await db
                .into(db.files)
                .insert(
                  FilesCompanion.insert(
                    path: pdf.path,
                    name: 'Rechnung.pdf',
                    size: pdf.lengthSync(),
                    pages: const Value(2),
                    created: DateTime(2026),
                    modified: DateTime(2026),
                  ),
                );
          });
        }
        await pumpAt(
          tester,
          location,
          locale: const Locale('de'),
          database: db,
          settle: !fileScreens.contains(location),
          overrides: [
            lockedVaultProvider.overrideWithValue(LockedSetup().vault),
            fileStoreProvider.overrideWith((ref) async => store),
          ],
        );
        // PDFium opens and renders off the test clock.
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(tester.takeException(), isNull);
        expect(cut(tester), isEmpty);
        // Let go of the PDF; pdfrx's page loader runs on a short timer.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}

bool _cut(RenderParagraph p) {
  if (!p.hasSize) return false;
  if (p.didExceedMaxLines) return true;
  return !p.softWrap &&
      p.getMaxIntrinsicWidth(double.infinity) > p.size.width + 0.5;
}

/// Cut in the design export's German frame too: Home's four-across tile
/// ends "Text durchsuchb…" (deutsch/02-home/home-default); DK-1139 asks
/// whether tool names may take a third line.
const _frameCuts = {'Text durchsuchbar machen'};
