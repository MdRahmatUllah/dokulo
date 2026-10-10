import 'package:app_pdf/components/dk_action_bar.dart';
import 'package:app_pdf/components/dk_page_thumb.dart';
import 'package:app_pdf/components/dk_segmented.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/l10n/formats.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/screens/t2_tool/tool_options_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:app_pdf/tools/img2pdf_tool.dart';
import 'package:app_pdf/tools/tool_definition.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Image to PDF's T2 (DK-0433; UI spec §21.7).
void main() {
  late DokuloDatabase db;
  late ProviderContainer container;
  late List<int> ids;

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
    int images = 12,
    DkTokens? tokens,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ids = (await tester.runAsync(
      () async => [
        for (var i = 1; i <= images; i++)
          await db
              .into(db.files)
              .insert(
                FilesCompanion.insert(
                  path: '/photos/IMG_000$i.jpg',
                  name: 'IMG_000$i.jpg',
                  size: 340000,
                  created: DateTime(2026),
                  modified: DateTime(2026),
                ),
              ),
      ],
    ))!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dokuloTheme(tokens ?? DkTokens.light),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ToolOptionsScreen(definition: img2pdfDefinition, fileIds: ids),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
  }

  DkActionBar bar(WidgetTester tester) =>
      tester.widget<DkActionBar>(find.byType(DkActionBar));

  testWidgets('the options with their defaults, the button and estimate', (
    tester,
  ) async {
    await pump(tester);
    for (final label in [
      'Page size',
      'Fit image',
      'A4',
      'Letter',
      'Margins',
      'None',
      'Small',
      'Output',
      'One PDF',
      'One per image',
      'Clean up like a scan',
      'Crop to the document and improve contrast',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    final selected = [
      for (final s in tester.widgetList<DkSegmented<Object>>(
        find.byWidgetPredicate((w) => w is DkSegmented),
      ))
        s.selected,
    ];
    expect(selected, [ImagePageSize.fit, false, false]);
    expect(bar(tester).label, 'Create PDF · 12 images');
    expect(
      bar(tester).caption,
      '1 PDF · 12 pages · about ${formatBytes(12 * 340000, 'en')}',
    );
  });

  testWidgets('the strip: a tap offers Remove; the count follows', (
    tester,
  ) async {
    await pump(tester, images: 3);
    expect(find.text('Images (3)'), findsOneWidget);
    await tester.tap(find.byType(DkPageThumb).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Images (2)'), findsOneWidget);
    expect(bar(tester).label, 'Create PDF · 2 images');
  });

  testWidgets('One per image: the estimate counts PDFs', (tester) async {
    await pump(tester, images: 3);
    await tester.tap(find.text('One per image'));
    await tester.pump();
    expect(bar(tester).caption, startsWith('3 PDFs · 3 pages'));
  });

  testWidgets('German: the button wraps whole', (tester) async {
    await pump(tester, locale: const Locale('de'));
    expect(bar(tester).label, 'PDF erstellen · 12 Bilder');
    expect(tester.takeException(), isNull);
  });

  test('the job input follows the options', () {
    final input = img2pdfDefinition.input!(
      ToolSubject([
        for (final n in ['a.jpg', 'b.heic.jpg'])
          FileEntry(
            id: n.length,
            path: '/p/$n',
            name: n,
            size: 1,
            pages: 0,
            created: DateTime(2026),
            modified: DateTime(2026),
            hasText: false,
            encrypted: false,
          ),
      ]),
      {
        'size': ImagePageSize.a4,
        'margins': true,
        'onePerImage': true,
        'cleanUp': true,
      },
      ToolEnv(
        outputDir: '/out',
        l10n: lookupAppLocalizations(const Locale('en')),
        skipPages: const {1},
      ),
    ) as Img2PdfInput;
    expect(input.files, ['/p/a.jpg', '/p/b.heic.jpg']);
    expect(input.size, ImagePageSize.a4);
    expect(input.margins && input.onePerImage && input.cleanUp, isTrue);
    expect(input.suffix, '', reason: 'named after the first image (§27.3)');
    expect(input.skipPages, [1]);
  });

  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('golden: img2pdf options, $theme', (tester) async {
      await pump(tester, tokens: tokens);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/img2pdf_options_$theme.png'),
      );
    });
  }
}
