import 'dart:io';
import 'dart:typed_data';

import 'package:app_pdf/components/dk_empty_state.dart';
import 'package:app_pdf/components/dk_file_card.dart';
import 'package:app_pdf/components/dk_tool_tile.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/providers/files_providers.dart';
import 'package:app_pdf/providers/prefs_providers.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/screens/home/home_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _WhitePages extends ThumbnailCache {
  _WhitePages() : super(Directory.systemTemp);

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
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: dokuloTheme(tokens ?? DkTokens.light),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
          final now = DateTime.now();
          await addFile(db, 'Mietvertrag Musterstraße 12.pdf', opened: now);
          await addFile(
            db,
            'Invoice INV-2026-014.pdf',
            opened: now.subtract(const Duration(hours: 3)),
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
