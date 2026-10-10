import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_core/ai_core.dart' show DeviceCapabilities;
import 'package:app_pdf/crash/crash_log.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/crash_providers.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/providers/device_providers.dart';
import 'package:app_pdf/providers/file_providers.dart';
import 'package:app_pdf/providers/job_providers.dart';
import 'package:app_pdf/providers/mail_providers.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/screens/t2_tool/tool_options_providers.dart';
import 'package:app_pdf/screens/t2_tool/tool_options_screen.dart';
import 'package:app_pdf/screens/t2_tool/tool_run.dart';
import 'package:app_pdf/screens/t3_result/tool_result_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:app_pdf/theme/haptics.dart';
import 'package:app_pdf/tools/tool_definition.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

// Visual QA (DK-0838, DK-0842, DK-0843, DK-0844, DK-0847; DK-0845, DK-0846,
// DK-0855, DK-0856; DK-0853, DK-0854, DK-0857): the T2, X2 and T3 frames of
// 12-tool-shell (t2empty, lockedrow, btnloading, progress, failure;
// minibar, canceldlg, discard, aftersave; savemenu, replace, replaced),
// rendered by the real screens in each state at 393 × 852. The goldens
// sit next to the frames' screenshots in docs/qa/tool-shell/; the findings
// are in docs/qa/design-system.md. A tool's own options (Compress's levels)
// come with its task (DK-0463), so the boards show the shell.

String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

final _compress = ToolDefinition(
  id: 'compress',
  action: (l, s) => 'Compress ${s.pages} pages',
  busyLabel: (l) => 'Compressing…',
  busyTitle: (l, s) => 'Compressing ${s.files.first.name}',
  input: (s, v, env) => {...v, 'skipPages': env.skipPages},
  canSkipPages: true,
);

final _merge = ToolDefinition(
  id: 'merge',
  action: (l, s) => 'Merge ${s.files.length} files',
  input: (s, v, env) => v,
);

/// A 1 × 1 grey PNG: a photo for the board (an image decodes by content).
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

class _Jobs extends RunningJobs {
  _Jobs(this.jobs);
  final List<RunningJob> jobs;

  @override
  List<RunningJob> build() => jobs;
}

class _Run {
  final progress = StreamController<JobProgress>.broadcast();
  final result = Completer<Object?>();

  ToolRunHandle get handle => (
    progress: progress.stream,
    result: result.future,
    cancel: () {},
    discard: () async {},
  );
}

void main() {
  setUpAll(pdfrxInitialize);
  final sep = Platform.pathSeparator;
  late Directory root;
  late DokuloDatabase db;
  late FileStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dk_qa_t2_');
    db = DokuloDatabase.memory();
    store = FileStore(
      userFolder: Directory('${root.path}${sep}Dokulo'),
      workDirectory: Directory('${root.path}${sep}sandbox'),
    );
  });
  tearDown(() async {
    await db.close();
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // A decoder still holding a file on Windows: the OS cleans temp.
    }
  });

  /// A file of the frame's, from [source], with the frame's size and pages.
  Future<int> file(
    WidgetTester tester,
    String name, {
    String source = 'Invoice INV-2026-014.pdf',
    int size = 1000,
    int pages = 1,
    DateTime? modified,
    List<int>? bytes,
  }) async => (await tester.runAsync(() async {
    final f = File('${store.userFolder.path}$sep$name')
      ..parent.createSync(recursive: true);
    if (bytes != null) {
      await f.writeAsBytes(bytes);
    } else {
      await File(fixture(source)).copy(f.path);
    }
    final id = await db
        .into(db.files)
        .insert(
          FilesCompanion.insert(
            path: f.path,
            name: name,
            size: size,
            created: DateTime(2026),
            modified: modified ?? DateTime(2026, 10, 1),
          ),
        );
    await db.customStatement('UPDATE files SET pages = ? WHERE id = ?', [
      pages,
      id,
    ]);
    return id;
  }))!;

  Future<void> pump(
    WidgetTester tester,
    DkTokens tokens,
    ToolDefinition def,
    List<int> ids, {
    _Run? run,
    List<Override> extra = const [],
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          fileStoreProvider.overrideWith((ref) async => store),
          if (run != null)
            toolRunnerProvider.overrideWithValue(
              (id, input) async => run.handle,
            ),
          ...extra,
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dokuloTheme(tokens),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ToolOptionsScreen(definition: def, fileIds: ids),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> golden(WidgetTester tester, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/tool_shell_$name.png'),
  );

  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('t2empty, $theme: "Choose a PDF", the recent PDFs, Browse '
        'device; the button waits', (tester) async {
      var day = 9;
      for (final (name, size, pages) in [
        ('Mietvertrag Musterstraße 12.pdf', 8400000, 12),
        ('Invoice INV-2026-014.pdf', 186000, 2),
        ('Finanzamt München – Bescheid 2025.pdf', 640000, 4),
        ('Whiteboard notes.pdf', 3200000, 1),
        ('Lebenslauf Max Mustermann.pdf', 412000, 2),
      ]) {
        await file(
          tester,
          name,
          size: size,
          pages: pages,
          modified: DateTime(2026, 10, day--),
        );
      }
      await pump(tester, tokens, _compress, const []);
      await golden(tester, 't2empty_$theme');
    });

    testWidgets('lockedrow, $theme: four files, the locked one with its '
        'unlock row', (tester) async {
      final ids = [
        await file(tester, 'Anschreiben.pdf'),
        await file(tester, 'Lebenslauf Max Mustermann.pdf', pages: 2),
        await file(
          tester,
          'Zeugnisse.pdf',
          source: 'encrypted-aes256.pdf',
          pages: 34,
        ),
        await file(tester, 'Personalausweis.jpg', bytes: _png),
      ];
      await pump(tester, tokens, _merge, ids);
      await golden(tester, 'lockedrow_$theme');
    });

    testWidgets('btnloading, $theme: "Compressing…" after 2 s', (tester) async {
      final id = await file(
        tester,
        'Mietvertrag Musterstraße 12.pdf',
        size: 8400000,
        pages: 12,
      );
      final run = _Run();
      await pump(tester, tokens, _compress, [id], run: run);
      await tester.tap(find.text('Compress 12 pages'));
      await tester.pump(const Duration(seconds: 3));
      await golden(tester, 'btnloading_$theme');
      run.result.complete(null);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('progress, $theme: the sheet after 10 s', (tester) async {
      final id = await file(
        tester,
        'Mietvertrag.pdf',
        size: 8400000,
        pages: 12,
      );
      final run = _Run();
      await pump(tester, tokens, _compress, [id], run: run);
      await tester.tap(find.text('Compress 12 pages'));
      await tester.pump(const Duration(seconds: 3));
      run.progress.add(
        const JobProgress(
          'reading',
          pageIndex: 17,
          pageCount: 40,
          etaSeconds: 20,
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await golden(tester, 'progress_$theme');
      run.result.complete(null);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('failure, $theme: the error state with its code line', (
      tester,
    ) async {
      final id = await file(
        tester,
        'Mietvertrag Musterstraße 12.pdf',
        size: 8400000,
        pages: 12,
      );
      final run = _Run();
      await pump(tester, tokens, _compress, [id], run: run);
      await tester.tap(find.text('Compress 12 pages'));
      await tester.pump();
      run.result.completeError(
        const DocError(DocErrorKind.unexpected, page: 13),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.text('Something went wrong on page 14.'), findsOneWidget);
      expect(find.text('Code DK-0190'), findsOneWidget);
      await golden(tester, 'failure_$theme');
    });

    if (theme == 'light') {
      testWidgets('Send report by email (DK-1080): a draft with the code, '
          'the device and the log in the mail app', (tester) async {
        final id = await file(tester, 'Mietvertrag.pdf', pages: 12);
        final mails = <Uri>[];
        final log = CrashLog(
          File('${Directory.systemTemp.createTempSync('dk_log_').path}/l'),
        );
        final run = _Run();
        await pump(
          tester,
          tokens,
          _compress,
          [id],
          run: run,
          extra: [
            mailComposerProvider.overrideWithValue((uri) async {
              mails.add(uri);
              return true;
            }),
            crashLogProvider.overrideWith((ref) async => log),
            deviceCapabilitiesProvider.overrideWith(
              (ref) async => const DeviceCapabilities(
                totalRam: 6000000000,
                abis: ['arm64-v8a'],
                os: 'android',
                osVersion: '15',
              ),
            ),
          ],
        );
        await tester.tap(find.text('Compress 12 pages'));
        await tester.pump();
        run.result.completeError(const DocError(DocErrorKind.unexpected));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        await tester.tap(find.text('Send report by email'));
        await settle(tester);
        expect(mails, hasLength(1));
        expect(mails.single.scheme, 'mailto');
        expect(mails.single.toString(), contains('DK-0190'));
        expect(
          Uri.decodeComponent(mails.single.toString()),
          contains('android 15'),
        );
      });
    }

    if (theme == 'light') {
      testWidgets('Skip this page (DK-1086): reruns with the failed page '
          'skipped', (tester) async {
        final id = await file(tester, 'Mietvertrag.pdf', pages: 20);
        final inputs = <Object>[];
        final runs = [_Run(), _Run()];
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              fileStoreProvider.overrideWith((ref) async => store),
              toolRunnerProvider.overrideWithValue((id, input) async {
                inputs.add(input('out'));
                return runs[inputs.length - 1].handle;
              }),
            ],
            child: MaterialApp(
              theme: dokuloTheme(tokens),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: ToolOptionsScreen(definition: _compress, fileIds: [id]),
            ),
          ),
        );
        await settle(tester);
        await tester.tap(find.text('Compress 20 pages'));
        await tester.pump();
        runs[0].result.completeError(
          const DocError(DocErrorKind.unexpected, page: 13),
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        await tester.tap(find.text('Skip this page'));
        await tester.pump();
        expect(inputs, hasLength(2));
        expect((inputs.last as Map)['skipPages'], {13});
        runs[1].result.complete(null);
        await tester.pump(const Duration(seconds: 1));
      });
    }

    testWidgets('minibar, $theme: a running job above the tab bar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = buildRouter(initialLocation: Routes.tools);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            runningJobsProvider.overrideWith(
              () => _Jobs([
                RunningJob(
                  id: 1,
                  toolId: 'compress',
                  cancel: () {},
                  progress: const JobProgress(
                    'reading',
                    pageIndex: 17,
                    pageCount: 40,
                  ),
                ),
              ]),
            ),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            routerConfig: router,
            theme: dokuloTheme(tokens),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await settle(tester);
      await golden(tester, 'minibar_$theme');
    });

    testWidgets('canceldlg, $theme: "Stop compressing?" after 30 s', (
      tester,
    ) async {
      final id = await file(
        tester,
        'Mietvertrag Musterstraße 12.pdf',
        size: 8400000,
        pages: 12,
      );
      final run = _Run();
      final def = ToolDefinition(
        id: 'compress',
        action: (l, s) => 'Compress ${s.pages} pages',
        stopTitle: (l) => 'Stop compressing?',
        input: (s, v, env) => v,
      );
      await pump(tester, tokens, def, [id], run: run);
      await tester.tap(find.text('Compress 12 pages'));
      for (var i = 0; i < 31; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.tap(find.text('Cancel'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.text('Stop compressing?'), findsOneWidget);
      await golden(tester, 'canceldlg_$theme');
      run.result.complete(null);
      await tester.pump(const Duration(seconds: 1));
    });

    Future<void> pumpT3(WidgetTester tester, Duration took) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final id = await file(
        tester,
        'Mietvertrag Musterstraße 12.pdf',
        size: 8400000,
        pages: 12,
      );
      final out = (await tester.runAsync(() async {
        final f = await store.newTempFile(
          'Mietvertrag Musterstraße 12 – compressed.pdf',
        );
        await File(fixture('Invoice INV-2026-014.pdf')).copy(f.path);
        return f.path;
      }))!;
      final input = (await tester.runAsync(
        () => (db.select(db.files)..where((f) => f.id.equals(id))).getSingle(),
      ))!;
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          fileStoreProvider.overrideWith((ref) async => store),
          hapticsProvider.overrideWithValue(DkHaptics(medium: () async {})),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(lastToolResultProvider.notifier)
          .set(
            ToolResult(
              toolId: 'compress',
              inputs: [input],
              output: OneFile(out),
              took: took,
            ),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dokuloTheme(tokens),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ToolResultScreen(toolId: 'compress'),
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets("discard, $theme: closing a long job's unsaved result", (
      tester,
    ) async {
      await pumpT3(tester, const Duration(seconds: 15));
      await tester.tap(find.byTooltip('Close'));
      await settle(tester);
      expect(find.text('Discard this result?'), findsOneWidget);
      await golden(tester, 'discard_$theme');
    });

    // DK-0854, DK-0857: Replace original from the split Save.
    Future<void> replaceDialog(WidgetTester tester) async {
      await pumpT3(tester, const Duration(seconds: 3));
      await tester.tap(find.bySemanticsLabel('More ways to save'));
      await settle(tester);
      await tester.tap(find.text('Replace original'));
      await settle(tester);
    }

    testWidgets('savemenu, $theme: Save as copy · Replace original · Save '
        'to…', (tester) async {
      await pumpT3(tester, const Duration(seconds: 3));
      await tester.tap(find.bySemanticsLabel('More ways to save'));
      await settle(tester);
      expect(find.text('Save to…'), findsOneWidget);
      await golden(tester, 'savemenu_$theme');
    });

    testWidgets('replace, $theme: "Replace the original file?"', (
      tester,
    ) async {
      await replaceDialog(tester);
      expect(find.text('Replace the original file?'), findsOneWidget);
      await golden(tester, 'replace_$theme');
    });

    testWidgets('replaced, $theme: "Replaced · Undo" and Done', (tester) async {
      await replaceDialog(tester);
      await tester.tap(find.text('Replace'));
      for (var i = 0; i < 3; i++) {
        await settle(tester);
      }
      expect(find.text('Replaced'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      await golden(tester, 'replaced_$theme');
    });

    testWidgets('aftersave, $theme: the toast and Done', (tester) async {
      await pumpT3(tester, const Duration(seconds: 3));
      await tester.tap(find.text('Save'));
      for (var i = 0; i < 3; i++) {
        await settle(tester);
      }
      expect(find.text('Done'), findsOneWidget);
      await golden(tester, 'aftersave_$theme');
    });
  }
}

/// The database, the lock check (PDFium) and the thumbnails between frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}
