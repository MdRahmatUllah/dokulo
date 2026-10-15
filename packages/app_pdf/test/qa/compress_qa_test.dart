import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/screens/t2_tool/tool_options_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:app_pdf/tools/compress_tool.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import '../screens/viewer_screen_test.dart' show fixture, settle;

// Visual QA (DK-0860, DK-0969, DK-0971): Compress PDF's T2 (DK-0463) with
// More options open on the phone (12-tool-shell/tool-shell-moreopts), and on
// the large tablet in landscape (1366 × 1024) and the small tablet in
// portrait (820 × 1180) (24-tablet/tablet-compress-options-*), the frame's
// 12-page lease of 8.4 MB. Frames in docs/qa/tool-shell/ and docs/qa/tablet/;
// findings in docs/qa/design-system.md and docs/qa/tablet.md. T3 on the
// large tablet (DK-0970) is in tool_shell_test.
void main() {
  setUpAll(pdfrxInitialize); // the large tablet's preview pane
  late DokuloDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = DokuloDatabase.memory();
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pump(
    WidgetTester tester, {
    required DkTokens tokens,
    Locale locale = const Locale('en'),
    Size size = const Size(393, 852),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final id = (await tester.runAsync(() async {
      final id = await db
          .into(db.files)
          .insert(
            FilesCompanion.insert(
              path: fixture('Mietvertrag Musterstraße 12.pdf'),
              name: 'Mietvertrag Musterstraße 12.pdf',
              size: 8400000,
              created: DateTime(2026),
              modified: DateTime(2026),
            ),
          );
      await db.customStatement('UPDATE files SET pages = 12 WHERE id = ?', [
        id,
      ]);
      return id;
    }))!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dokuloTheme(tokens),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ToolOptionsScreen(definition: compressDefinition, fileIds: [id]),
        ),
      ),
    );
    await settle(tester, rounds: 20);
  }

  Future<void> shot(WidgetTester tester, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/qa_compress_$name.png'),
  );

  for (final (theme, tokens, locale) in [
    ('light', DkTokens.light, const Locale('en')),
    ('dark', DkTokens.dark, const Locale('en')),
    ('deutsch', DkTokens.light, const Locale('de')),
  ]) {
    testWidgets('tool-shell-moreopts (More options open), $theme', (
      tester,
    ) async {
      await pump(tester, tokens: tokens, locale: locale);
      final more = lookupAppLocalizations(locale).common_more_options;
      await tester.ensureVisible(find.text(more));
      await tester.tap(find.text(more));
      await tester.pumpAndSettle();
      await shot(tester, 'moreopts_$theme');
    });
  }

  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('tablet-compress-options-landscape, $theme', (tester) async {
      await pump(tester, tokens: tokens, size: const Size(1366, 1024));
      await shot(tester, 'tablet_landscape_$theme');
    });

    testWidgets('tablet-compress-options-portrait, $theme', (tester) async {
      await pump(tester, tokens: tokens, size: const Size(820, 1180));
      await shot(tester, 'tablet_portrait_$theme');
    });
  }
}
