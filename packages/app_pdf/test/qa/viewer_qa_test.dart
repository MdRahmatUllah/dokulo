import 'dart:io';

import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/providers/file_providers.dart';
import 'package:app_pdf/providers/link_providers.dart';
import 'package:app_pdf/providers/prefs_providers.dart';
import 'package:app_pdf/screens/v1_viewer/viewer_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import '../screens/viewer_screen_test.dart' show fixture, settle;

// Visual QA (DK-0763, DK-0764, DK-0765, DK-0766, DK-0767, DK-0771, DK-0773,
// DK-0775, DK-0777): the 06-viewer frames default, hidden, loading, search,
// searchnotext, night, form, link and thumbs, rendered by the real V1 at
// 393 × 852 in light, dark and German. The frames' screenshots are in
// docs/qa/viewer/; the findings in docs/qa/viewer.md (with agent-0's
// locked/damaged pass, DK-0769 to DK-0778).
void main() {
  setUpAll(pdfrxInitialize);
  late Directory root;
  late DokuloDatabase db;
  late FileStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dk_qa_v1_');
    db = DokuloDatabase.memory();
    store = FileStore(
      userFolder: Directory('${root.path}/Dokulo'),
      workDirectory: Directory('${root.path}/work'),
    );
  });
  tearDown(() async {
    await db.close();
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // PDFium may still hold the file on Windows: the OS cleans temp.
    }
  });

  for (final (theme, tokens, locale) in [
    ('light', DkTokens.light, const Locale('en')),
    ('dark', DkTokens.dark, const Locale('en')),
    ('deutsch', DkTokens.light, const Locale('de')),
  ]) {
    final l = lookupAppLocalizations(locale);

    /// V1 on [source] (a corpus file), named as the frame's file.
    Future<void> pump(
      WidgetTester tester,
      String source, {
      String name = 'Mietvertrag Musterstraße 12.pdf',
      String? query,
      bool night = false,
      bool ready = true,
    }) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final id = (await tester.runAsync(() async {
        Directory('${root.path}/Dokulo').createSync(recursive: true);
        final copy = await File(source).copy('${root.path}/Dokulo/$name');
        return db
            .into(db.files)
            .insert(
              FilesCompanion.insert(
                path: copy.path,
                name: name,
                size: 1,
                created: DateTime(2026),
                modified: DateTime(2026),
              ),
            );
      }))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            fileStoreProvider.overrideWith((ref) async => store),
            prefsProvider.overrideWith(
              () => Prefs.memory({viewerNightKey: night}),
            ),
            linkOpenerProvider.overrideWithValue((url) async => true),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dokuloTheme(tokens),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ViewerScreen(fileId: id, query: query),
          ),
        ),
      );
      if (ready) await settle(tester, rounds: 40);
    }

    Future<void> shot(WidgetTester tester, String frame) => expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/qa_viewer_${frame}_$theme.png'),
    );

    final lease = fixture('Mietvertrag Musterstraße 12.pdf');

    testWidgets('viewer-default, $theme', (tester) async {
      await pump(tester, lease);
      await shot(tester, 'default');
    });

    testWidgets('viewer-hidden (a tap hides the bars), $theme', (
      tester,
    ) async {
      await pump(tester, lease);
      await tester.tapAt(const Offset(196, 500));
      await settle(tester, rounds: 10);
      await shot(tester, 'hidden');
    });

    testWidgets('viewer-loading, $theme', (tester) async {
      await pump(tester, lease, ready: false);
      await tester.pump();
      await shot(tester, 'loading');
      await settle(tester, rounds: 20); // let PDFium finish before teardown
    });

    testWidgets('viewer-search ("Mieter"), $theme', (tester) async {
      await pump(tester, lease, query: 'Mieter');
      await shot(tester, 'search');
    });

    testWidgets('viewer-searchnotext (a scan), $theme', (tester) async {
      await pump(
        tester,
        fixture('scanned-letters-bundle.pdf'),
        name: 'Scan 14.10.2026.pdf',
        query: 'Rechnung',
      );
      await settle(tester, rounds: 30);
      await shot(tester, 'searchnotext');
    });

    testWidgets('viewer-night, $theme', (tester) async {
      await pump(tester, lease, night: true);
      await shot(tester, 'night');
    });

    testWidgets('viewer-form (the form banner), $theme', (tester) async {
      await pump(
        tester,
        fixture('form-acroform.pdf'),
        name: 'Anmeldung Sportverein.pdf',
      );
      await shot(tester, 'form');
    });

    testWidgets('viewer-thumbs (More › Pages), $theme', (tester) async {
      await pump(tester, lease);
      final more = MaterialLocalizations.of(
        tester.element(find.byType(ViewerScreen)),
      ).moreButtonTooltip;
      await tester.tap(find.byTooltip(more));
      await settle(tester, rounds: 5);
      await tester.tap(find.text(l.viewer_menu_pages));
      await settle(tester, rounds: 20);
      await shot(tester, 'thumbs');
    });
  }
}
