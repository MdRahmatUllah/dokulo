import 'dart:async';
import 'dart:io';

import 'package:app_pdf/components/dk_button.dart';
import 'package:app_pdf/components/dk_pdf_canvas.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/providers/prefs_providers.dart';
import 'package:app_pdf/screens/v1_viewer/viewer_screen.dart';
import 'package:app_pdf/screens/v1_viewer/viewer_search.dart';
import 'package:app_pdf/screens/v1_viewer/viewer_states.dart';
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

Widget app(Widget child, {DkTokens? tokens, Locale? locale}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
  locale: locale,
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

  testWidgets('V1 says so when the file is gone, instead of spinning', (
    tester,
  ) async {
    final db = DokuloDatabase.memory();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: app(const ViewerScreen(fileId: 404)),
      ),
    );
    await settle(tester, rounds: 5);
    expect(find.text("This file isn't in Dokulo any more."), findsOneWidget);
    expect(find.byType(PdfViewer), findsNothing);
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

  Future<int> addFile(
    WidgetTester tester,
    DokuloDatabase db,
    String path,
  ) async => (await tester.runAsync(
    () => db
        .into(db.files)
        .insert(
          FilesCompanion.insert(
            path: path,
            name: path.split(RegExp(r'[\/]')).last,
            size: 1,
            created: DateTime(2026),
            modified: DateTime(2026),
          ),
        ),
  ))!;

  // Visual QA (DK-0769, DK-0770, DK-0772, DK-0778): the frames are in
  // docs/qa/viewer/, the findings in docs/qa/viewer.md.
  for (final (theme, tokens, locale) in [
    ('light', DkTokens.light, const Locale('en')),
    ('dark', DkTokens.dark, const Locale('en')),
    ('deutsch', DkTokens.light, const Locale('de')),
  ]) {
    final en = locale.languageCode == 'en';
    testWidgets('locked (DK-0301, DK-0302, DK-0303): the card, a wrong '
        'password, then the pages and "Unlocked for viewing" ($theme)', (
      tester,
    ) async {
      final db = DokuloDatabase.memory();
      addTearDown(db.close);
      final id = await addFile(tester, db, fixture('encrypted-aes256.pdf'));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: app(
            Scaffold(body: ViewerScreen(fileId: id)),
            tokens: tokens,
            locale: locale,
          ),
        ),
      );
      await settle(tester);
      expect(find.byType(ViewerLockedCard), findsOneWidget);
      if (en) expect(find.text('This PDF is locked'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/viewer_locked_$theme.png'),
      );
      await tester.enterText(find.byType(TextField), 'wrong');
      await tester.tap(find.byType(DkButton));
      await settle(tester);
      if (en) {
        expect(
          find.text("That password doesn't open this file."),
          findsOneWidget,
        );
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/viewer_wrongpw_$theme.png'),
      );
      await tester.enterText(find.byType(TextField), 'dokulo');
      await tester.tap(find.byType(DkButton));
      await settle(tester);
      expect(find.byType(PdfViewer), findsOneWidget);
      if (en) {
        expect(find.text('Unlocked for viewing'), findsOneWidget);
        expect(find.text('Remove password'), findsOneWidget);
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/viewer_unlocked_$theme.png'),
      );
    });

    testWidgets('damaged (DK-0305): "This file cannot be opened", Close and '
        'Try Repair ($theme)', (tester) async {
      final dir = Directory.systemTemp.createTempSync('dk_v1_bad_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final bad = File('${dir.path}/broken.pdf')
        ..writeAsStringSync('%PDF-1.7 not really a pdf');
      final db = DokuloDatabase.memory();
      addTearDown(db.close);
      final id = await addFile(tester, db, bad.path);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: app(
            ViewerScreen(fileId: id),
            tokens: tokens,
            locale: locale,
          ),
        ),
      );
      await settle(tester);
      expect(find.byType(ViewerDamaged), findsOneWidget);
      if (en) {
        expect(find.text("This file can't be opened."), findsOneWidget);
        expect(find.text('Try Repair'), findsOneWidget);
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/viewer_damaged_$theme.png'),
      );
    });
  }

  testWidgets('night mode (DK-1089): the pages through the night filter on '
      'the night canvas', (tester) async {
    final db = DokuloDatabase.memory();
    addTearDown(db.close);
    final id = await addFile(
      tester,
      db,
      fixture('Mietvertrag Musterstraße 12.pdf'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          prefsProvider.overrideWith(
            () => Prefs.memory({viewerNightKey: true}),
          ),
        ],
        child: app(ViewerScreen(fileId: id)),
      ),
    );
    await settle(tester);
    expect(find.byType(ColorFiltered), findsOneWidget);
    expect(tester.widget<DkPdfCanvas>(find.byType(DkPdfCanvas)).night, isTrue);
  });

  for (final (name, expected) in [
    ('form-acroform.pdf', true),
    ('Invoice INV-2026-014.pdf', false),
  ]) {
    testWidgets('form banner (DK-1090) on $name: $expected', (tester) async {
      final db = DokuloDatabase.memory();
      addTearDown(db.close);
      final id = await addFile(tester, db, fixture(name));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: app(ViewerScreen(fileId: id)),
        ),
      );
      await settle(tester);
      expect(
        find.text('This PDF has fillable fields.'),
        expected ? findsOneWidget : findsNothing,
      );
      if (expected) expect(find.text('Fill form'), findsOneWidget);
    });
  }

  testWidgets('search (DK-1093): opened with words, the bar counts the '
      'matches and Done closes it', (tester) async {
    final db = DokuloDatabase.memory();
    addTearDown(db.close);
    final id = await addFile(
      tester,
      db,
      fixture('Mietvertrag Musterstraße 12.pdf'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: app(ViewerScreen(fileId: id, query: 'Mieter')),
      ),
    );
    await settle(tester, rounds: 60);
    expect(find.byType(ViewerSearchBar), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d+ of \d+$')), findsOneWidget);
    expect(find.text('This scan has no searchable text.'), findsNothing);
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.byType(ViewerSearchBar), findsNothing);
  });

  testWidgets('search on a scan without text: the banner with Make '
      'searchable', (tester) async {
    final db = DokuloDatabase.memory();
    addTearDown(db.close);
    final id = await addFile(tester, db, fixture('scanned-letters-bundle.pdf'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: app(ViewerScreen(fileId: id, query: 'Rechnung')),
      ),
    );
    await settle(tester, rounds: 60);
    expect(find.text('This scan has no searchable text.'), findsOneWidget);
    expect(find.text('Make searchable'), findsOneWidget);
    expect(find.text('0 results'), findsOneWidget);
  });
}
