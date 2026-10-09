import 'dart:io';

import 'package:app_pdf/components/dk_action_bar.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/providers/file_providers.dart';
import 'package:app_pdf/routes/link_error.dart';
import 'package:app_pdf/screens/t2_tool/tool_options_providers.dart';
import 'package:app_pdf/screens/t3_result/tool_result_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:app_pdf/theme/haptics.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';

String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

void main() {
  setUpAll(pdfrxInitialize);
  final sep = Platform.pathSeparator;
  late Directory root;
  late FileStore store;
  late DokuloDatabase db;
  late File output;
  late FileEntry input;
  var saves = 0;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dk_t3_');
    store = FileStore(
      userFolder: Directory('${root.path}${sep}Dokulo'),
      workDirectory: Directory('${root.path}${sep}sandbox'),
    );
    db = DokuloDatabase.memory();
    saves = 0;
  });
  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
  });

  /// T3 in the place of its T2, over where the tool was started.
  Future<GoRouter> pumpT3(
    WidgetTester tester, {
    Duration took = const Duration(seconds: 3),
    bool result = true,
    DkTokens? tokens,
  }) async {
    await tester.runAsync(() async {
      final inputFile = File(
        '${store.userFolder.path}${sep}Taxes${sep}Mietvertrag.pdf',
      )..parent.createSync(recursive: true);
      await File(fixture('Invoice INV-2026-014.pdf')).copy(inputFile.path);
      final id = await db
          .into(db.files)
          .insert(
            FilesCompanion.insert(
              path: inputFile.path,
              name: 'Mietvertrag.pdf',
              size: 8400000,
              created: DateTime(2026),
              modified: DateTime(2026),
            ),
          );
      input = await (db.select(
        db.files,
      )..where((f) => f.id.equals(id))).getSingle();
      output = await store.newTempFile('Mietvertrag – compressed.pdf');
      await File(fixture('Invoice INV-2026-014.pdf')).copy(output.path);
    });
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        fileStoreProvider.overrideWith((ref) async => store),
        hapticsProvider.overrideWithValue(
          DkHaptics(medium: () async => saves++),
        ),
      ],
    );
    addTearDown(container.dispose);
    if (result) {
      container
          .read(lastToolResultProvider.notifier)
          .set(
            ToolResult(
              toolId: 'compress',
              inputs: [input],
              output: OneFile(output.path),
              took: took,
            ),
          );
    }
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('Start')),
        GoRoute(
          path: '/tool/:id',
          builder: (_, _) => const Text('T2'),
          routes: [
            GoRoute(
              path: 'result',
              builder: (_, s) =>
                  ToolResultScreen(toolId: s.pathParameters['id']!),
            ),
          ],
        ),
        GoRoute(path: '/viewer/:id', builder: (_, _) => const Text('V1')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: dokuloTheme(tokens ?? DkTokens.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    router.push('/tool/compress');
    await tester.pumpAndSettle();
    // As T2 does when the job is done.
    router.pushReplacement('/tool/compress/result');
    await settle(tester);
    return router;
  }

  DkActionBar bar(WidgetTester tester) =>
      tester.widget<DkActionBar>(find.byType(DkActionBar));

  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('golden: tool_result_$theme', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpT3(tester, tokens: tokens);
      await expectLater(
        find.byType(ToolResultScreen),
        matchesGoldenFile('goldens/tool_result_$theme.png'),
      );
    });
  }

  testWidgets('Save keeps a new file next to the input, indexed; medium '
      'haptic; "Saved to Files › Taxes" with Open; then Done (DK-0381)', (
    tester,
  ) async {
    final router = await pumpT3(tester);
    expect(find.text('Compress PDF'), findsOneWidget);
    expect(find.text('Save to: Files › Taxes'), findsOneWidget);
    expect(bar(tester).label, 'Save');

    // A name without its extension keeps the output's.
    await tester.enterText(find.byType(TextField), 'Mietvertrag klein');
    await tester.tap(find.text('Save'));
    await settle(tester);
    final saved = File(
      '${store.userFolder.path}${sep}Taxes${sep}Mietvertrag klein.pdf',
    );
    expect(saved.existsSync(), isTrue);
    expect(output.existsSync(), isFalse);
    final rows = await tester.runAsync(() => db.select(db.files).get());
    expect(rows!.map((r) => r.path), contains(saved.path));
    expect(saves, 1);
    expect(find.text('Saved to Files › Taxes'), findsOneWidget);
    expect(bar(tester).label, 'Done');

    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(
      find.text('Start'),
      findsOneWidget,
      reason: 'back where the tool started',
    );
    expect(router.canPop(), isFalse);
  });

  testWidgets('closing an unsaved result of a long job asks; Discard drops it '
      '(DK-0382)', (tester) async {
    await pumpT3(tester, took: const Duration(seconds: 15));
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    expect(find.text('Discard this result?'), findsOneWidget);
    await tester.tap(find.text('Keep'));
    await settle(tester);
    expect(find.byType(ToolResultScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    await tester.tap(find.text('Discard'));
    await settle(tester);
    expect(find.text('Start'), findsOneWidget);
    expect(output.existsSync(), isFalse, reason: 'nothing kept');
  });

  testWidgets('a short job closes silently', (tester) async {
    await pumpT3(tester);
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    expect(find.text('Discard this result?'), findsNothing);
    expect(find.text('Start'), findsOneWidget);
    expect(output.existsSync(), isFalse);
  });

  testWidgets('a link to a result that is gone says so', (tester) async {
    await pumpT3(tester, result: false);
    expect(find.byType(LinkErrorScreen), findsOneWidget);
  });
}

/// File work and transitions: real I/O between frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}
