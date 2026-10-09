import 'dart:io';
import 'dart:typed_data';

import 'package:app_pdf/components/dk_empty_state.dart';
import 'package:app_pdf/components/dk_file_card.dart';
import 'package:app_pdf/components/dk_folder_card.dart';
import 'package:app_pdf/components/dk_skeleton.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/providers/file_providers.dart';
import 'package:app_pdf/providers/files_providers.dart';
import 'package:app_pdf/providers/prefs_providers.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/screens/files/files_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// No PDFium in widget tests: every thumbnail is a small white page.
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

class _Fixture {
  _Fixture() : db = DokuloDatabase.memory();
  final DokuloDatabase db;
  late final Directory root;
  late final FileStore store;
  final prefs = <String, Object?>{};

  Future<void> setUp() async {
    root = await Directory.systemTemp.createTemp('dk_f1_');
    store = FileStore(
      userFolder: Directory('${root.path}/Dokulo'),
      workDirectory: Directory('${root.path}/work'),
    );
  }

  Future<void> tearDown() async {
    await db.close();
    await root.delete(recursive: true);
  }

  Future<int> file(
    String name, {
    int size = 1000,
    int pages = 2,
    DateTime? modified,
    int? folder,
  }) => db
      .into(db.files)
      .insert(
        FilesCompanion.insert(
          path: '${root.path}/Dokulo/$name',
          name: name,
          size: size,
          pages: Value(pages),
          created: modified ?? DateTime(2026, 10, 1),
          modified: modified ?? DateTime(2026, 10, 1),
          folderId: Value(folder),
        ),
      );

  Future<int> folder(String name, {String? tag}) => db
      .into(db.folders)
      .insert(FoldersCompanion.insert(name: name, colourTag: Value(tag)));
}

Future<GoRouter> pumpFiles(
  WidgetTester tester,
  _Fixture f, {
  DkTokens? tokens,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = buildRouter(initialLocation: Routes.files);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(f.db),
        prefsProvider.overrideWith(() => Prefs.memory(f.prefs)),
        fileStoreProvider.overrideWith((ref) async => f.store),
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

/// Drift's streams and the thumbnails answer on real time.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }
}

List<String> names(WidgetTester tester) => [
  for (final card in tester.widgetList<DkFileCard>(find.byType(DkFileCard)))
    card.name,
];

void main() {
  late _Fixture f;
  setUp(() async {
    f = _Fixture();
    await f.setUp();
  });
  tearDown(() => f.tearDown());

  testWidgets('empty root: the empty state, Scan a document', (tester) async {
    final router = await pumpFiles(tester, f);
    expect(find.byType(DkEmptyState), findsOneWidget);
    expect(find.text('No files yet'), findsOneWidget);
    expect(find.text('Locked folder'), findsOneWidget);
    await tester.tap(find.text('Scan a document'));
    await settle(tester);
    expect(router.state.uri.path, Routes.scan);
  });

  testWidgets('folders with counts, files with their meta; trash hidden', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final taxes = await f.folder('Taxes', tag: 'blue');
      await f.folder('Apartment');
      await f.file('in-taxes.pdf', folder: taxes);
      await f.file('Mietvertrag.pdf', size: 2400000, pages: 12);
      final gone = await f.file('Alt.pdf');
      await f.db
          .into(f.db.trash)
          .insert(
            TrashCompanion.insert(
              fileId: Value(gone),
              deletedAt: DateTime(2026, 10, 2),
            ),
          );
    });
    final router = await pumpFiles(tester, f);
    expect(
      [
        for (final c in tester.widgetList<DkFolderCard>(
          find.byType(DkFolderCard),
        ))
          (c.name, c.files),
      ],
      [('Apartment', 0), ('Taxes', 1)],
    );
    expect(names(tester), ['Mietvertrag.pdf']);
    expect(find.textContaining('2.4${' '}MB · 12 pages'), findsOneWidget);
    // Recently deleted shows its count.
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('Taxes'));
    await settle(tester);
    expect(router.state.uri.path, '/files/folder/1');
    router.go(Routes.files);
    await settle(tester);
    await tester.tap(find.text('Mietvertrag.pdf'));
    await settle(tester);
    expect(router.state.uri.path, startsWith('/viewer/'));
  });

  testWidgets('the grid toggle switches and is kept', (tester) async {
    await tester.runAsync(() async {
      await f.file('a.pdf');
      await f.folder('Work');
    });
    await pumpFiles(tester, f);
    expect(
      tester.widget<DkFileCard>(find.byType(DkFileCard)).variant,
      DkFileCardVariant.list,
    );
    await tester.tap(find.byTooltip('Grid view'));
    await settle(tester);
    expect(
      tester.widget<DkFileCard>(find.byType(DkFileCard)).variant,
      DkFileCardVariant.grid,
    );
    expect(tester.widget<DkFolderCard>(find.byType(DkFolderCard)).grid, isTrue);
    expect(find.byTooltip('List view'), findsOneWidget);
  });

  testWidgets('sort: date modified by default; Name, ascending', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await f.file('b.pdf', modified: DateTime(2026, 10, 3));
      await f.file('C.pdf', modified: DateTime(2026, 10, 1));
      await f.file('a.pdf', modified: DateTime(2026, 10, 2));
    });
    await pumpFiles(tester, f);
    expect(names(tester), ['b.pdf', 'a.pdf', 'C.pdf']);
    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name'));
    await settle(tester);
    expect(names(tester), ['C.pdf', 'b.pdf', 'a.pdf']);
    await tester.tap(find.byTooltip('Sort'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text('Name')).flagsCollection.isChecked,
      isTrue,
    );
    await tester.tap(find.text('Ascending'));
    await settle(tester);
    expect(names(tester), ['a.pdf', 'b.pdf', 'C.pdf']);
  });

  testWidgets('New folder: made on disk and listed; a taken name is refused', (
    tester,
  ) async {
    await pumpFiles(tester, f);
    await tester.tap(find.byTooltip('New folder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Taxes');
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Create'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await settle(tester);
    expect(find.text('Create'), findsNothing, reason: 'the dialog closed');
    expect(Directory('${f.root.path}/Dokulo/Taxes').existsSync(), isTrue);
    expect(find.text('Taxes'), findsOneWidget);

    await tester.tap(find.byTooltip('New folder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'taxes');
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Create'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(
      find.text('A folder with this name already exists.'),
      findsOneWidget,
    );
  });

  testWidgets('loading: the skeleton until the index answers', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = buildRouter(initialLocation: Routes.files);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(f.db),
          prefsProvider.overrideWith(() => Prefs.memory()),
          foldersProvider(null).overrideWith((ref) => const Stream.empty()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: dokuloTheme(DkTokens.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(DkSkeleton), findsOneWidget);
  });

  test('the meta line: size · pages · when', () async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final now = DateTime(2026, 10, 9, 16);
    FileEntry entry(DateTime modified) => FileEntry(
      id: 1,
      path: 'x',
      name: 'x.pdf',
      size: 2400000,
      pages: 12,
      created: modified,
      modified: modified,
      hasText: false,
      encrypted: false,
    );
    expect(
      fileMeta(entry(DateTime(2026, 10, 9, 14, 32)), l, 'en', now: now),
      '2.4 MB · 12 pages · Today 14:32',
    );
    expect(
      fileMeta(entry(DateTime(2026, 10, 8, 18, 20)), l, 'en', now: now),
      endsWith('Yesterday 18:20'),
    );
    expect(
      fileMeta(entry(DateTime(2026, 10, 5)), l, 'en', now: now),
      endsWith('5 Oct'),
    );
    expect(
      fileMeta(entry(DateTime(2025, 3, 1)), l, 'en', now: now),
      endsWith('1 Mar 2025'),
    );
  });

  group('goldens', () {
    for (final (name, tokens, locale, grid) in [
      ('list_light', DkTokens.light, const Locale('en'), false),
      ('list_dark', DkTokens.dark, const Locale('en'), false),
      ('list_de', DkTokens.light, const Locale('de'), false),
      ('grid_light', DkTokens.light, const Locale('en'), true),
    ]) {
      testWidgets(name, (tester) async {
        f.prefs['files.grid'] = grid;
        await tester.runAsync(() async {
          await f.folder('Taxes', tag: 'blue');
          await f.folder('Apartment', tag: 'green');
          final now = DateTime.now();
          await f.file(
            'Mietvertrag Musterstraße 12.pdf',
            size: 2400000,
            pages: 12,
            modified: now,
          );
          await f.file(
            'Invoice INV-2026-014.pdf',
            size: 186000,
            pages: 2,
            modified: now.subtract(const Duration(hours: 5)),
          );
          await f.file(
            'Lebenslauf.pdf',
            size: 412000,
            pages: 2,
            modified: DateTime(2026, 3, 3),
          );
        });
        await pumpFiles(tester, f, tokens: tokens, locale: locale);
        await expectLater(
          find.byType(FilesScreen),
          matchesGoldenFile('goldens/files_$name.png'),
        );
      });
    }
  });
}
