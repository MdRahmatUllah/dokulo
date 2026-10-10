import 'dart:io';
import 'dart:ui' show CheckedState;
import 'dart:typed_data';

import 'package:app_pdf/components/dk_confirm_dialog.dart';
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
import 'package:app_pdf/screens/settings/files_settings_screen.dart';
import 'package:app_pdf/screens/v1_viewer/viewer_providers.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// No PDFium in widget tests: every thumbnail is a small white page.
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

class FilesFixture {
  FilesFixture() : db = DokuloDatabase.memory();
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
  FilesFixture f, {
  DkTokens? tokens,
  Locale locale = const Locale('en'),
  String location = Routes.files,
  List<Override> overrides = const [],
  bool settled = true, // false: a shimmering skeleton never settles
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = buildRouter(initialLocation: location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(f.db),
        prefsProvider.overrideWith(() => Prefs.memory(f.prefs)),
        fileStoreProvider.overrideWith((ref) async => f.store),
        thumbnailCacheProvider.overrideWith((ref) async => _WhitePages()),
        modelsDirectoryProvider.overrideWith(
          (ref) async => Directory('${f.root.path}/models'),
        ),
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
      ),
    ),
  );
  settled ? await settle(tester) : await tester.pump();
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

/// The text field in an open dialog (F1's search field is a field too).
/// A file card's More button (a labelled node, no tooltip).
Finder get cardMore => find
    .byWidgetPredicate((w) => w is Semantics && w.properties.label == 'More')
    .first;

Finder get dialogField => find.descendant(
  of: find.byType(DkConfirmDialog),
  matching: find.byType(EditableText),
);

List<String> names(WidgetTester tester) => [
  for (final card in tester.widgetList<DkFileCard>(find.byType(DkFileCard)))
    card.name,
];

void main() {
  late FilesFixture f;
  setUp(() async {
    f = FilesFixture();
    await f.setUp();
  });
  tearDown(() => f.tearDown());

  testWidgets('empty root: the empty state, Scan a document', (tester) async {
    final router = await pumpFiles(tester, f);
    expect(find.byType(DkEmptyState), findsOneWidget);
    expect(find.text('No files yet'), findsOneWidget);
    expect(find.text('Locked folder'), findsOneWidget);
    expect(find.text('Open a file'), findsOneWidget);
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
      CheckedState.isTrue,
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
    await tester.enterText(dialogField, 'Taxes');
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
    await tester.enterText(dialogField, 'taxes');
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

  group('the folder screen (DK-0262)', () {
    late int taxes, year;

    Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
      taxes = await f.store.createFolder(f.db, 'Taxes');
      year = await f.store.createFolder(f.db, '2026', parent: taxes);
      final pdf = File('${f.root.path}/Dokulo/Taxes/2026/Bescheid.pdf')
        ..createSync(recursive: true)
        ..writeAsStringSync('%PDF');
      await f.db
          .into(f.db.files)
          .insert(
            FilesCompanion.insert(
              path: pdf.path,
              name: 'Bescheid.pdf',
              size: 4,
              created: DateTime(2026, 10, 1),
              modified: DateTime(2026, 10, 1),
              folderId: Value(year),
            ),
          );
    });

    testWidgets('title, breadcrumb, files with their count', (tester) async {
      await seed(tester);
      final router = await pumpFiles(tester, f, location: Routes.folder(year));
      expect(find.text('2026'), findsWidgets);
      expect(find.text('Taxes'), findsOneWidget, reason: 'breadcrumb');
      expect(find.text('1 file'), findsOneWidget);
      expect(find.text('Bescheid.pdf'), findsOneWidget);
      expect(find.text('Locked folder'), findsNothing, reason: 'root only');
      // A breadcrumb part opens that level.
      await tester.tap(find.text('Taxes'));
      await settle(tester);
      expect(router.state.uri.path, Routes.folder(taxes));
      await tester.tap(find.text('Files').first);
      await settle(tester);
      expect(router.state.uri.path, Routes.files);
    });

    testWidgets('an empty folder shows its empty state', (tester) async {
      await seed(tester);
      final empty = (await tester.runAsync(
        () => f.store.createFolder(f.db, 'Leer'),
      ))!;
      await pumpFiles(tester, f, location: Routes.folder(empty));
      expect(find.text('This folder is empty'), findsOneWidget);
    });

    testWidgets('Rename folder renames it on disk and in the title', (
      tester,
    ) async {
      await seed(tester);
      await pumpFiles(tester, f, location: Routes.folder(taxes));
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename folder'));
      await tester.pumpAndSettle();
      await tester.enterText(dialogField, 'Steuern');
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('Rename'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await settle(tester);
      expect(find.text('Steuern'), findsWidgets);
      expect(
        Directory('${f.root.path}/Dokulo/Steuern/2026').existsSync(),
        isTrue,
      );
    });

    testWidgets('Colour tags the folder everywhere', (tester) async {
      await seed(tester);
      await pumpFiles(tester, f, location: Routes.folder(taxes));
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Colour'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Green'));
      await settle(tester);
      final row = await tester.runAsync(
        () => (f.db.select(
          f.db.folders,
        )..where((x) => x.id.equals(taxes))).getSingle(),
      );
      expect(row!.colourTag, 'green');
    });

    testWidgets('Delete folder asks first when it holds files', (tester) async {
      await seed(tester);
      final router = await pumpFiles(tester, f, location: Routes.folder(taxes));
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Delete folder'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('Delete “Taxes”?'), findsOneWidget);
      expect(find.text('Its file moves to Recently deleted.'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Delete folder').last);
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await settle(tester);
      expect(router.state.uri.path, Routes.files);
      expect(
        await tester.runAsync(() => f.db.select(f.db.folders).get()),
        isEmpty,
      );
      expect(
        await tester.runAsync(() => f.db.select(f.db.trash).get()),
        hasLength(1),
      );
    });
  });

  group('file actions (DK-0271, DK-0272, DK-0274, DK-0276)', () {
    late int id;
    Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
      final pdf = File('${f.root.path}/Dokulo/Vertrag.pdf')
        ..createSync(recursive: true)
        ..writeAsStringSync('%PDF');
      id = await f.db
          .into(f.db.files)
          .insert(
            FilesCompanion.insert(
              path: pdf.path,
              name: 'Vertrag.pdf',
              size: 4,
              created: DateTime(2026, 10, 1),
              modified: DateTime(2026, 10, 1),
            ),
          );
    });

    Future<void> openSheet(WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.tap(cardMore);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
    }

    Future<void> tapReal(WidgetTester tester, Finder finder) async {
      // The medium sheet scrolls: its last rows start below the fold.
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(finder);
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await settle(tester);
    }

    Future<FileEntry> row(WidgetTester tester, int id) async =>
        (await tester.runAsync(
          () => (f.db.select(
            f.db.files,
          )..where((x) => x.id.equals(id))).getSingle(),
        ))!;

    testWidgets('the sheet: header, Open/Share, 5 tools, the actions', (
      tester,
    ) async {
      await seed(tester);
      await pumpFiles(tester, f);
      await openSheet(tester);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      for (final tool in [
        'Compress PDF',
        'Sign PDF',
        'Add password',
        'Black out (redact)',
      ]) {
        expect(find.text(tool), findsOneWidget, reason: tool);
      }
      for (final action in [
        'All tools…',
        'Rename',
        'Duplicate',
        'Move',
        'Move to locked folder',
        'Delete',
      ]) {
        expect(find.text(action), findsOneWidget, reason: action);
      }
    });

    testWidgets('Rename keeps .pdf; a taken name is refused inline', (
      tester,
    ) async {
      await seed(tester);
      await tester.runAsync(
        () async =>
            File('${f.root.path}/Dokulo/Taken.pdf').writeAsStringSync('x'),
      );
      await pumpFiles(tester, f);
      await openSheet(tester);
      await tester.ensureVisible(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      expect(
        find.text('.pdf'),
        findsOneWidget,
        reason: 'the extension is shown, not edited',
      );
      await tester.enterText(dialogField, 'Taken');
      await tester.pump();
      await tapReal(tester, find.text('Rename').last);
      expect(
        find.text('A file with this name already exists.'),
        findsOneWidget,
      );
      await tester.enterText(dialogField, 'Mietvertrag');
      await tester.pump();
      await tapReal(tester, find.text('Rename').last);
      expect((await row(tester, id)).name, 'Mietvertrag.pdf');
    });

    testWidgets('Duplicate makes (2) with Undo', (tester) async {
      await seed(tester);
      await pumpFiles(tester, f);
      await openSheet(tester);
      await tapReal(tester, find.text('Duplicate'));
      expect(find.text('Duplicated as Vertrag (2).pdf'), findsOneWidget);
      expect(find.text('Vertrag (2).pdf'), findsOneWidget);
      await tapReal(tester, find.text('Undo'));
      expect(find.text('Vertrag (2).pdf'), findsNothing);
      expect(
        File('${f.root.path}/Dokulo/Vertrag (2).pdf').existsSync(),
        isFalse,
      );
    });

    testWidgets('Delete moves to Recently deleted; Undo brings it back', (
      tester,
    ) async {
      await seed(tester);
      await pumpFiles(tester, f);
      await openSheet(tester);
      await tapReal(tester, find.text('Delete'));
      expect(find.text('Moved to Recently deleted'), findsOneWidget);
      expect(find.text('Vertrag.pdf'), findsNothing);
      await tapReal(tester, find.text('Undo'));
      expect(find.text('Vertrag.pdf'), findsOneWidget);
    });

    testWidgets('Move: into a folder from the sheet, Undo moves it back', (
      tester,
    ) async {
      await seed(tester);
      late int taxes;
      await tester.runAsync(() async {
        taxes = await f.store.createFolder(f.db, 'Taxes');
      });
      await pumpFiles(tester, f);
      await openSheet(tester);
      await tester.ensureVisible(find.text('Move'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move'));
      await settle(tester);
      expect(find.text('Move 1 file'), findsOneWidget);
      await tester.tap(find.text('Taxes').last);
      await settle(tester);
      await tapReal(tester, find.text('Move here'));
      expect(find.text('Moved to Taxes'), findsOneWidget);
      expect((await row(tester, id)).folderId, taxes);
      await tapReal(tester, find.text('Undo'));
      expect((await row(tester, id)).folderId, isNull);
    });
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
          // Fixed times today: "5 hours ago" read "Yesterday" after
          // midnight, a different golden.
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          await f.file(
            'Mietvertrag Musterstraße 12.pdf',
            size: 2400000,
            pages: 12,
            modified: today.add(const Duration(hours: 14, minutes: 32)),
          );
          await f.file(
            'Invoice INV-2026-014.pdf',
            size: 186000,
            pages: 2,
            modified: today.add(const Duration(hours: 9, minutes: 32)),
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
