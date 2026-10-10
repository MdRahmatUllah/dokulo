import 'dart:io';
import 'dart:typed_data';

import 'package:app_pdf/components/dk_empty_state.dart';
import 'package:app_pdf/components/dk_file_card.dart';
import 'package:app_pdf/components/dk_mini_job_bar.dart';
import 'package:app_pdf/components/dk_tool_tile.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/patterns/dk_open_file.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/providers/file_providers.dart';
import 'package:app_pdf/providers/files_providers.dart';
import 'package:app_pdf/providers/job_providers.dart';
import 'package:app_pdf/providers/prefs_providers.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/screens/home/home_screen.dart';
import 'package:app_pdf/screens/v1_viewer/viewer_providers.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart' show JobProgress;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _WhitePages extends ThumbnailCache {
  // Never the system temp itself: Clear cache deletes this folder.
  _WhitePages()
    : super(Directory('${Directory.systemTemp.path}/dk_test_thumbs'));

  @override
  Future<RenderedPage> thumbnail(
    String path,
    int page, {
    int width = 96,
  }) async => RenderedPage(
    width: 3,
    height: 4,
    bgra: Uint8List.fromList(List.filled(3 * 4 * 4, 0xFF)),
  );
}

Future<GoRouter> pumpHome(
  WidgetTester tester,
  DokuloDatabase db, {
  DkTokens? tokens,
  Locale locale = const Locale('en'),
  List<Override> overrides = const [],
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = buildRouter(initialLocation: Routes.home);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        prefsProvider.overrideWith(() => Prefs.memory()),
        thumbnailCacheProvider.overrideWith((ref) async => _WhitePages()),
        // V1 without PDFium: the file reads as missing, so no canvas opens.
        viewerFileProvider.overrideWith(
          (ref, fileId) async => throw StateError('no PDFium in tests'),
        ),
        ...overrides,
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: dokuloTheme(tokens ?? DkTokens.light),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await settle(tester);
  return router;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }
}

Future<int> addFile(
  DokuloDatabase db,
  String name, {
  required DateTime opened,
}) async {
  final id = await db
      .into(db.files)
      .insert(
        FilesCompanion.insert(
          path: '/x/$name',
          name: name,
          size: 186000,
          pages: const Value(2),
          created: DateTime(2026, 10, 1),
          modified: opened,
        ),
      );
  await db
      .into(db.recents)
      .insert(RecentsCompanion.insert(fileId: Value(id), openedAt: opened));
  return id;
}

void main() {
  late DokuloDatabase db;
  setUp(() => db = DokuloDatabase.memory());
  tearDown(() => db.close());

  testWidgets('first launch: the 8 default tools and the empty state', (
    tester,
  ) async {
    await pumpHome(tester, db);
    expect([
      for (final t in tester.widgetList<DkToolTile>(find.byType(DkToolTile)))
        t.toolId,
    ], defaultPinnedTools);
    expect(find.text('Everything stays on this phone'), findsOneWidget);
    expect(find.text('Open a file'), findsOneWidget);
    expect(find.byType(DkEmptyState), findsOneWidget);
    expect(find.text('Your scans and PDFs will appear here'), findsOneWidget);
    expect(find.text('Recent'), findsNothing);
  });

  testWidgets('Recent: newest first; a tap opens V1 and moves it up', (
    tester,
  ) async {
    late int older;
    await tester.runAsync(() async {
      older = await addFile(db, 'Old.pdf', opened: DateTime(2026, 10, 1));
      await addFile(db, 'New.pdf', opened: DateTime(2026, 10, 5));
    });
    final router = await pumpHome(tester, db);
    expect(find.text('Recent'), findsOneWidget);
    expect(
      [
        for (final c in tester.widgetList<DkFileCard>(find.byType(DkFileCard)))
          c.name,
      ],
      ['New.pdf', 'Old.pdf'],
    );
    await tester.tap(find.text('Old.pdf'));
    await settle(tester);
    expect(router.state.uri.path, '/viewer/$older');
    final top = await tester.runAsync(
      () =>
          (db.select(db.recents)
                ..orderBy([(r) => OrderingTerm.desc(r.openedAt)])
                ..limit(1))
              .getSingle(),
    );
    expect(top!.fileId, older);
  });

  testWidgets(
    'a file added but not opened is in Recent; the empty state goes',
    (tester) async {
      await tester.runAsync(
        () => db
            .into(db.files)
            .insert(
              FilesCompanion.insert(
                path: '/x/Scan.pdf',
                name: 'Scan.pdf',
                size: 1000,
                created: DateTime(2026, 10, 9),
                modified: DateTime(2026, 10, 9),
              ),
            ),
      );
      await pumpHome(tester, db);
      expect(find.byType(DkEmptyState), findsNothing);
      expect(find.text('Scan.pdf'), findsOneWidget);
    },
  );

  testWidgets('Recent holds 20 at most', (tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 25; i++) {
        await addFile(db, 'f$i.pdf', opened: DateTime(2026, 10, 1, i));
      }
    });
    await pumpHome(tester, db);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    expect(container.read(recentFilesProvider).value, hasLength(20));
    expect(container.read(recentFilesProvider).value!.first.name, 'f24.pdf');
  });

  testWidgets('a running job: the mini bar never covers the last row', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 12; i++) {
        await addFile(db, 'f$i.pdf', opened: DateTime(2026, 10, 1, i));
      }
    });
    await pumpHome(
      tester,
      db,
      overrides: [runningJobsProvider.overrideWith(_OneJob.new)],
    );
    expect(find.byType(DkMiniJobBar), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await settle(tester);
    final last = tester.getRect(find.text('f0.pdf'));
    expect(
      last.bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(DkMiniJobBar)).top),
    );
  });

  testWidgets('Open a file: picked, copied into Dokulo, at the top, in V1', (
    tester,
  ) async {
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('dk_h1_'),
    ))!;
    addTearDown(() => root.delete(recursive: true));
    final picked = File('${root.path}/Downloads/Vertrag.pdf')
      ..createSync(recursive: true)
      ..writeAsStringSync('%PDF-1.7');
    final store = FileStore(
      userFolder: Directory('${root.path}/Dokulo'),
      workDirectory: Directory('${root.path}/work'),
    );
    final router = await pumpHome(
      tester,
      db,
      overrides: [
        pickPdfProvider.overrideWithValue(() async => picked.path),
        fileStoreProvider.overrideWith((ref) async => store),
      ],
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Open a file'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await settle(tester);
    expect(router.state.uri.path, startsWith('/viewer/'));
    expect(File('${root.path}/Dokulo/Vertrag.pdf').existsSync(), isTrue);
    final recents = await tester.runAsync(() => db.select(db.recents).get());
    expect(recents, hasLength(1));
  });

  testWidgets('pinned tools come from the table, in order', (tester) async {
    await tester.runAsync(() async {
      for (final (i, id) in ['ocr', 'merge'].indexed) {
        await db
            .into(db.pinnedTools)
            .insert(PinnedToolsCompanion.insert(toolId: id, position: i));
      }
    });
    await pumpHome(tester, db);
    expect(
      [
        for (final t in tester.widgetList<DkToolTile>(find.byType(DkToolTile)))
          t.toolId,
      ],
      ['ocr', 'merge'],
    );
  });

  testWidgets('a tool opens T2; search opens Files; settings opens Me', (
    tester,
  ) async {
    final router = await pumpHome(tester, db);
    await tester.tap(find.text('Compress PDF'));
    await settle(tester);
    expect(router.state.uri.path, Routes.tool('compress'));
    router.go(Routes.home);
    await settle(tester);

    await tester.tap(find.byTooltip('Search files'));
    await settle(tester);
    expect(router.state.uri.toString(), Routes.filesSearch);

    router.go(Routes.home);
    await settle(tester);
    await tester.tap(find.byTooltip('Settings'));
    await settle(tester);
    expect(router.state.uri.path, Routes.me);
  });

  group('goldens', () {
    for (final (name, tokens, locale) in [
      ('light', DkTokens.light, const Locale('en')),
      ('dark', DkTokens.dark, const Locale('en')),
      ('de', DkTokens.light, const Locale('de')),
    ]) {
      testWidgets(name, (tester) async {
        await tester.runAsync(() async {
          // Fixed times today, so the meta reads "Today 14:32" whenever
          // the test runs (3 hours before now read "Yesterday" after
          // midnight, a wider text).
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          await addFile(
            db,
            'Mietvertrag Musterstraße 12.pdf',
            opened: today.add(const Duration(hours: 14, minutes: 32)),
          );
          await addFile(
            db,
            'Invoice INV-2026-014.pdf',
            opened: today.add(const Duration(hours: 11, minutes: 32)),
          );
        });
        await pumpHome(tester, db, tokens: tokens, locale: locale);
        await expectLater(
          find.byType(HomeScreen),
          matchesGoldenFile('goldens/home_$name.png'),
        );
      });
    }
    testWidgets('first launch', (tester) async {
      await pumpHome(tester, db);
      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_first_light.png'),
      );
    });
  });
}

/// One Compress job half done.
class _OneJob extends RunningJobs {
  @override
  List<RunningJob> build() => [
    RunningJob(
      id: 1,
      toolId: 'compress',
      cancel: () {},
      progress: const JobProgress('compress', pageIndex: 2, pageCount: 4),
    ),
  ];
}
