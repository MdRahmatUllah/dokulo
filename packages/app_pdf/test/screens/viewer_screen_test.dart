import 'dart:async';
import 'dart:io';

import 'package:app_pdf/components/dk_pdf_canvas.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/screens/v1_viewer/viewer_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

/// The shared sample corpus (DK-0023), from the repo root.
String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

Widget app(Widget child, {DkTokens? tokens}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

/// Lets real async work (drift, PDFium on pdfrx's worker) finish and draws.
Future<void> settle(WidgetTester tester, {int rounds = 30}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(
    pdfrxInitialize,
  ); // PDFium for this machine; the app calls pdfrxFlutterInitialize

  setUp(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..physicalSize =
          const Size(393, 852) // the phone frame
      ..devicePixelRatio = 1;
  });
  tearDown(
    () => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .reset(),
  );

  testWidgets('V1 opens the file by its id and shows its pages on the canvas', (
    tester,
  ) async {
    final db = DokuloDatabase.memory();
    addTearDown(db.close);
    final id = await tester.runAsync(
      () => db
          .into(db.files)
          .insert(
            FilesCompanion.insert(
              path: fixture('Mietvertrag Musterstraße 12.pdf'),
              name: 'Mietvertrag Musterstraße 12.pdf',
              size: 1,
              created: DateTime(2026),
              modified: DateTime(2026),
            ),
          ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: app(ViewerScreen(fileId: id!)),
      ),
    );
    await settle(tester);
    expect(find.byType(PdfViewer), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, DkTokens.light.color.surfaceSunken);
  });

  testWidgets(
    'the canvas opens at fit width; a double tap fits again after zooming; page jump',
    (tester) async {
      final controller = PdfViewerController();
      await tester.pumpWidget(
        app(
          Scaffold(
            body: DkPdfCanvas(
              path: fixture('long-300-pages.pdf'),
              controller: controller,
            ),
          ),
        ),
      );
      await settle(tester);
      expect(controller.isReady, isTrue);

      double fitWidth() =>
          (393 - 2 * DkPdfCanvas.gap) /
          controller.layout.pageLayouts.first.width;
      expect(
        controller.currentZoom,
        closeTo(fitWidth(), 0.02),
        reason: 'fit width on open',
      );

      // The animations run on the test's clock: start them, then pump it.
      unawaited(controller.setZoom(const Offset(196, 400), 3));
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester, rounds: 6);
      expect(controller.currentZoom, closeTo(3, 0.05));

      final centre = tester.getCenter(find.byType(DkPdfCanvas));
      await tester.tapAt(centre);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(centre);
      await settle(tester, rounds: 10);
      expect(
        controller.currentZoom,
        closeTo(fitWidth(), 0.02),
        reason: 'double tap fits the width again',
      );

      unawaited(controller.goToPage(pageNumber: 150));
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester, rounds: 10);
      expect(controller.pageNumber, 150, reason: 'page jump');
    },
  );

  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('golden: the first page at fit width, $name', (tester) async {
      await tester.pumpWidget(
        app(
          Scaffold(
            body: DkPdfCanvas(path: fixture('Mietvertrag Musterstraße 12.pdf')),
          ),
          tokens: tokens,
        ),
      );
      await settle(tester, rounds: 40);
      await expectLater(
        find.byType(DkPdfCanvas),
        matchesGoldenFile('goldens/viewer_canvas_$name.png'),
      );
    });
  }
}
