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
import 'package:app_pdf/tools/tool_definition.dart';
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
  late List<String> partFiles;
  var saves = 0;
  final elsewhere = <(String, String)>[];

  setUp(() {
    root = Directory.systemTemp.createTempSync('dk_t3_');
    store = FileStore(
      userFolder: Directory('${root.path}${sep}Dokulo'),
      workDirectory: Directory('${root.path}${sep}sandbox'),
    );
    db = DokuloDatabase.memory();
    saves = 0;
    elsewhere.clear();
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
    int parts = 1,
    ToolDefinition? definition,
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
      partFiles = [];
      for (var i = 1; i <= parts && parts > 1; i++) {
        final part = await store.newTempFile('Zeugnisse – part $i.pdf');
        await File(fixture('Invoice INV-2026-014.pdf')).copy(part.path);
        partFiles.add(part.path);
      }
    });
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        fileStoreProvider.overrideWith((ref) async => store),
        hapticsProvider.overrideWithValue(
          DkHaptics(medium: () async => saves++),
        ),
        saveElsewhereProvider.overrideWithValue((path, name) async {
          elsewhere.add((path, name));
          return true;
        }),
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
              output: parts > 1 ? ManyFiles(partFiles) : OneFile(output.path),
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
              builder: (_, s) => ToolResultScreen(
                toolId: s.pathParameters['id']!,
                definition: definition,
              ),
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

  testWidgets('Replace original (DK-0380): the split menu, the dialog, the '
      'output over the file, the original in Versions, Undo for 10 s', (
    tester,
  ) async {
    await pumpT3(tester);
    final original = File(input.path).readAsBytesSync();
    // A different result, so a replace shows.
    await tester.runAsync(
      () => File(output.path).writeAsBytes([...original, 0x0A]),
    );
    await tester.tap(find.bySemanticsLabel('More ways to save'));
    await settle(tester);
    expect(find.text('Save as copy'), findsOneWidget);
    await tester.tap(find.text('Replace original'));
    await settle(tester);
    expect(find.text('Replace the original file?'), findsOneWidget);
    expect(
      find.text('The original will be kept in Versions for 30 days.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Replace'));
    await settle(tester);
    expect(File(input.path).lengthSync(), original.length + 1);
    final versions = await tester.runAsync(() => db.select(db.versions).get());
    expect(versions, hasLength(1));
    expect(File(versions!.single.path).readAsBytesSync(), original);
    expect(find.text('Replaced'), findsOneWidget);
    expect(bar(tester).label, 'Done');
    expect(saves, 1);
    final toast = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(toast.duration, const Duration(seconds: 10));

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(File(input.path).readAsBytesSync(), original);
  });

  testWidgets('a multi-file result: Save as copy and Save to…, no Replace', (
    tester,
  ) async {
    await pumpT3(tester, parts: 3);
    await tester.tap(find.bySemanticsLabel('More ways to save'));
    await settle(tester);
    expect(find.text('Save to…'), findsOneWidget);
    expect(find.text('Replace original'), findsNothing);
  });

  testWidgets('Save to… (DK-0385): the folder picker, then Save here saves '
      'there; the row shows the folder', (tester) async {
    await pumpT3(tester);
    await tester.tap(find.bySemanticsLabel('More ways to save'));
    await settle(tester);
    await tester.tap(find.text('Save to…'));
    await settle(tester);
    // From Taxes up to the root, then Save here.
    await tester.tap(find.text('Files').last);
    await settle(tester);
    await tester.tap(find.text('Save here'));
    await settle(tester);
    final saved = File(
      '${store.userFolder.path}${sep}Mietvertrag – compressed.pdf',
    );
    expect(saved.existsSync(), isTrue);
    expect(find.text('Save to: Files'), findsOneWidget);
    expect(bar(tester).label, 'Done');
  });

  testWidgets('Save to… › Save outside Dokulo…: the system dialog gets the '
      'file and its name', (tester) async {
    await pumpT3(tester);
    await tester.tap(find.bySemanticsLabel('More ways to save'));
    await settle(tester);
    await tester.tap(find.text('Save to…'));
    await settle(tester);
    await tester.tap(find.text('Save outside Dokulo…'));
    await settle(tester);
    expect(elsewhere, [(output.path, 'Mietvertrag – compressed.pdf')]);
    expect(find.text('Saved'), findsOneWidget);
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
  testWidgets('a multi-file result: "3 files", one row per part with its '
      'line, no name field; Save keeps every part (DK-0384)', (tester) async {
    await pumpT3(
      tester,
      parts: 3,
      definition: ToolDefinition(
        id: 'compress',
        partLine: (l, r, i) => 'Pages ${i * 3 + 1}–${i * 3 + 3}',
      ),
    );
    expect(find.text('3 files'), findsNWidgets(2), reason: 'card and list');
    expect(find.text('From Mietvertrag.pdf'), findsOneWidget);
    expect(find.text('Zeugnisse – part 2.pdf'), findsOneWidget);
    expect(find.text('Pages 4–6'), findsOneWidget);
    expect(find.text('File name'), findsNothing);

    await tester.tap(find.text('Save'));
    // Three saves, each opening its PDF for the page count.
    for (var i = 0; i < 3; i++) {
      await settle(tester);
    }
    for (var i = 1; i <= 3; i++) {
      expect(
        File('${store.userFolder.path}${sep}Taxes${sep}Zeugnisse – part $i.pdf')
            .existsSync(),
        isTrue,
      );
    }
  });

  testWidgets('a partial result: the warning card with its inline action '
      '(DK-0383)', (tester) async {
    var retakes = 0;
    await pumpT3(
      tester,
      definition: ToolDefinition(
        id: 'compress',
        summary: (l, r) => ToolSummary(
          headline: 'Text found on 11 of 12 pages',
          sub: 'Page 7 is too blurry.',
          partial: true,
          action: 'Retake page 7',
          onAction: (_) => retakes++,
        ),
      ),
    );
    expect(find.text('Text found on 11 of 12 pages'), findsOneWidget);
    expect(find.text('Page 7 is too blurry.'), findsOneWidget);
    await tester.tap(find.text('Retake page 7'));
    expect(retakes, 1);
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
