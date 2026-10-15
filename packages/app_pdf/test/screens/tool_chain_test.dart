import 'dart:async';
import 'dart:io';

import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/providers/file_providers.dart';
import 'package:app_pdf/screens/t2_tool/tool_options_providers.dart';
import 'package:app_pdf/screens/t2_tool/tool_options_screen.dart';
import 'package:app_pdf/screens/t2_tool/tool_run.dart';
import 'package:app_pdf/screens/t3_result/tool_result_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
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

/// A tool that hands its input paths and output folder to the runner.
ToolDefinition _tool(String id, List<String> next) => ToolDefinition(
  id: id,
  next: next,
  input: (s, v, env) =>
      (paths: [for (final f in s.files) f.path], out: env.outputDir),
);

final _defs = {
  'compress': _tool('compress', ['ocr']),
  'ocr': _tool('ocr', ['protect']),
  'protect': _tool('protect', const []),
};

void main() {
  setUpAll(pdfrxInitialize);
  late Directory root;
  late DokuloDatabase db;
  late Map<String, List<String>> inputs;
  ProviderContainer? container;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dk_chain_');
    db = DokuloDatabase.memory();
    inputs = {};
  });
  tearDown(() async {
    container?.dispose();
    await db.close();
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // A decoder still holding a file on Windows: the OS cleans temp.
    }
  });

  /// Writes "<tool>-out.pdf" (the input's bytes) as the run's output.
  Future<ToolRunHandle> run(
    String toolId,
    Object Function(String outputDir) make,
  ) async {
    final out = Directory('${root.path}/$toolId')..createSync();
    final job = make(out.path) as ({List<String> paths, String out});
    inputs[toolId] = job.paths;
    final file = File('${job.out}/$toolId-out.pdf')
      ..writeAsBytesSync(File(job.paths.first).readAsBytesSync());
    return (
      progress: const Stream<JobProgress>.empty(),
      result: Future<Object?>.value(OneFile(file.path)),
      cancel: () {},
      discard: () async {},
    );
  }

  testWidgets('a chain of three tools: each Next chip hands the result on, '
      'no re-pick (DK-0386)', (tester) async {
    final id = (await tester.runAsync(() async {
      final original = File('${root.path}/Mietvertrag.pdf');
      await File(fixture('Invoice INV-2026-014.pdf')).copy(original.path);
      return db
          .into(db.files)
          .insert(
            FilesCompanion.insert(
              path: original.path,
              name: 'Mietvertrag.pdf',
              size: 1000,
              pages: const Value(2),
              created: DateTime(2026),
              modified: DateTime(2026),
            ),
          );
    }))!;
    final store = FileStore(
      userFolder: Directory('${root.path}/Dokulo'),
      workDirectory: Directory('${root.path}/sandbox'),
    );
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        fileStoreProvider.overrideWith((ref) async => store),
        toolRunnerProvider.overrideWithValue(run),
      ],
    );
    final router = GoRouter(
      initialLocation: '/tool/compress?file=$id',
      routes: [
        GoRoute(
          path: '/tool/:id',
          builder: (_, s) => ToolOptionsScreen(
            definition: _defs[s.pathParameters['id']]!,
            fileIds: [
              for (final f in s.uri.queryParametersAll['file'] ?? const [])
                int.parse(f),
            ],
            chained: s.uri.queryParameters['chain'] == '1',
          ),
          routes: [
            GoRoute(
              path: 'result',
              builder: (_, s) => ToolResultScreen(
                toolId: s.pathParameters['id']!,
                definition: _defs[s.pathParameters['id']],
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container!,
        child: MaterialApp.router(
          routerConfig: router,
          theme: dokuloTheme(DkTokens.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await settle(tester);

    Future<void> runTool(String name) async {
      await tester.tap(find.text(name).last); // the action bar's button
      await settle(tester);
    }

    await runTool('Compress PDF');
    expect(find.text('Next'), findsOneWidget);
    await tapChip(tester, 'Make text searchable');
    expect(find.text('compress-out.pdf'), findsOneWidget, reason: 'its input');

    await runTool('Make text searchable');
    await tapChip(tester, 'Add password');
    await runTool('Add password');

    expect(inputs['compress'], [endsWith('Mietvertrag.pdf')]);
    expect(inputs['ocr'], [endsWith('compress-out.pdf')]);
    expect(inputs['protect'], [endsWith('ocr-out.pdf')]);
    expect(container!.read(lastToolResultProvider)!.chain, [
      'compress',
      'ocr',
      'protect',
    ]);
    expect(find.text('Next'), findsNothing, reason: 'Add password has none');
  });
}

/// A Next chip, scrolled into the list's built range and out from under
/// the action bar first.
Future<void> tapChip(WidgetTester tester, String tool) async {
  await tester.scrollUntilVisible(
    find.text(tool),
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text(tool));
  await tester.pump();
  await tester.tap(find.text(tool));
  await settle(tester);
}

/// Files, PDFium and the transitions between frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}
