import 'package:app_pdf/components/dk_action_bar.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/l10n/formats.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/screens/t2_tool/tool_options_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:app_pdf/tools/compress_tool.dart';
import 'package:app_pdf/tools/tool_definition.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The copy's thin space between number and unit.
String u(String s) => s.replaceAllMapped(
  RegExp(r'(\d|≈) ([KM]B|\d)'),
  (m) => '${m[1]}$unitSpace${m[2]}',
);

void main() {
  late DokuloDatabase db;
  late List<int> ids;
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
    WidgetTester tester,
    List<(String, int, int)> files, {
    DkTokens? tokens,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ids = [];
    for (final (name, pages, size) in files) {
      await tester.runAsync(() async {
        final id = await db
            .into(db.files)
            .insert(
              FilesCompanion.insert(
                path: '/docs/$name',
                name: name,
                size: size,
                created: DateTime(2026),
                modified: DateTime(2026),
              ),
            );
        await db.customStatement('UPDATE files SET pages = ? WHERE id = ?', [
          pages,
          id,
        ]);
        ids.add(id);
      });
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dokuloTheme(tokens ?? DkTokens.light),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ToolOptionsScreen(definition: compressDefinition, fileIds: ids),
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

  test('it is the registered compress tool', () {
    expect(ToolDefinitions.of('compress'), same(compressDefinition));
  });

  testWidgets('defaults: Recommended with estimates; the count on the button', (
    tester,
  ) async {
    await pump(tester, [('Mietvertrag.pdf', 12, 8400000)]);
    expect(find.text(u('≈ 5.1 MB')), findsOneWidget);
    expect(find.text(u('≈ 1.9 MB')), findsOneWidget);
    expect(find.text(u('≈ 924 KB')), findsOneWidget);
    expect(bar(tester).label, 'Compress 12 pages');
    expect(bar(tester).caption, u('About 1.9 MB · 12 pages'));
  });

  testWidgets('a target clears the level and says what Dokulo will do', (
    tester,
  ) async {
    await pump(tester, [('Scan.pdf', 2, 6800000)]);
    await tester.tap(find.text(u('Under 2 MB')));
    await tester.pumpAndSettle();
    expect(
      find.text(u('Dokulo will find the best quality under 2 MB.')),
      findsOneWidget,
    );
    expect(bar(tester).caption, u('Target under 2 MB · 2 pages'));
    final input = compressDefinition.input!(
      ToolSubject([
        for (final id in ids)
          (await tester.runAsync(
            () => (db.select(
              db.files,
            )..where((f) => f.id.equals(id))).getSingle(),
          ))!,
      ]),
      {
        ...compressDefinition.initialValues,
        'size': (level: null, target: 2000000),
      },
      ToolEnv(
        outputDir: '/tmp',
        l10n: AppLocalizations.of(
          tester.element(find.byType(ToolOptionsScreen)),
        ),
      ),
    ) as CompressInput;
    expect(input.targetBytes, 2000000);
    expect(input.suffix, ' – compressed');
  });

  testWidgets('several files: "Compress 4 files"', (tester) async {
    await pump(tester, [for (var i = 0; i < 4; i++) ('f$i.pdf', 3, 1000000)]);
    expect(bar(tester).label, 'Compress 4 files');
  });

  testWidgets('German: the button wraps, not cut', (tester) async {
    await pump(tester, [('a.pdf', 12, 8400000)], locale: const Locale('de'));
    expect(bar(tester).label, '12 Seiten verkleinern');
  });

  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('golden: compress_options_$theme', (tester) async {
      await pump(tester, [
        ('Mietvertrag Musterstraße 12.pdf', 12, 8400000),
      ], tokens: tokens);
      await expectLater(
        find.byType(ToolOptionsScreen),
        matchesGoldenFile('goldens/compress_options_$theme.png'),
      );
    });
  }
}
