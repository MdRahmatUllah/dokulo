import 'dart:io';

import 'package:app_pdf/components/dk_page_grid.dart';
import 'package:app_pdf/components/dk_page_thumb.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/providers/file_providers.dart';
import 'package:app_pdf/screens/p1_organize/organize_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:app_pdf/theme/haptics.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';

String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

/// P1, Organize pages (DK-0329, DK-0331, DK-0332, DK-0333).
void main() {
  setUpAll(pdfrxInitialize);
  final sep = Platform.pathSeparator;
  late Directory root;
  late FileStore store;
  late DokuloDatabase db;
  late File original;
  var drops = 0;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dk_p1_');
    store = FileStore(
      userFolder: Directory('${root.path}${sep}Dokulo'),
      workDirectory: Directory('${root.path}${sep}sandbox'),
    );
    db = DokuloDatabase.memory();
    drops = 0;
  });
  tearDown(() async {
    await db.close();
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // A decoder still holding a file on Windows: the OS cleans temp.
    }
  });

  Future<void> pumpP1(WidgetTester tester, {DkTokens? tokens}) async {
    // A phone: three columns, so the 5 pages fit on screen.
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final id = (await tester.runAsync(() async {
      original = File('${store.userFolder.path}${sep}Taxes${sep}Five.pdf')
        ..parent.createSync(recursive: true);
      await PdfEngine.assemble([
        for (var i = 0; i < 5; i++)
          PageSource(fixture('long-300-pages.pdf'), i),
      ], original.path);
      return db
          .into(db.files)
          .insert(
            FilesCompanion.insert(
              path: original.path,
              name: 'Five.pdf',
              size: original.lengthSync(),
              created: DateTime(2026),
              modified: DateTime(2026),
            ),
          );
    }))!;
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('Viewer')),
        GoRoute(
          path: '/organize/:id',
          builder: (_, s) =>
              OrganizeScreen(fileId: int.parse(s.pathParameters['id']!)),
        ),
        GoRoute(path: '/viewer/:id', builder: (_, _) => const Text('V1')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          fileStoreProvider.overrideWith((ref) async => store),
          hapticsProvider.overrideWithValue(
            DkHaptics(light: () async => drops++, medium: () async {}),
          ),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: dokuloTheme(tokens ?? DkTokens.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    router.push('/organize/$id');
    await settle(tester);
  }

  int pageCount(WidgetTester tester) =>
      tester.widget<DkPageGrid>(find.byType(DkPageGrid)).pageIds.length;

  Future<void> tapPage(WidgetTester tester, int number) async {
    await tester.tap(
      find.byWidgetPredicate((w) => w is DkPageThumb && w.pageNumber == number),
    );
    await tester.pump();
  }

  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('golden: organize_$theme', (tester) async {
      await pumpP1(tester, tokens: tokens);
      await expectLater(
        find.byType(OrganizeScreen),
        matchesGoldenFile('goldens/organize_$theme.png'),
      );
    });
  }

  testWidgets('the screen: "Organize pages", "5 pages", the grid; select two '
      'and Delete: "2 pages deleted · Undo" (DK-0329, DK-0333)', (
    tester,
  ) async {
    await pumpP1(tester);
    expect(find.text('Organize pages'), findsOneWidget);
    expect(find.text('5 pages'), findsOneWidget);
    expect(pageCount(tester), 5);

    await tapPage(tester, 2);
    await tapPage(tester, 4);
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await settle(tester);
    expect(pageCount(tester), 3);
    expect(find.text('2 pages deleted'), findsOneWidget);
    await tester.tap(find.text('Undo').last);
    await settle(tester);
    expect(pageCount(tester), 5);
  });

  testWidgets('Duplicate, Rotate, Undo and Redo; a drop moves the page with '
      'its haptic (DK-0331)', (tester) async {
    await pumpP1(tester);
    await tapPage(tester, 1);
    await tester.tap(find.text('Duplicate'));
    await tester.pump();
    expect(pageCount(tester), 6);
    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(pageCount(tester), 5);
    await tester.tap(find.byTooltip('Redo'));
    await tester.pump();
    expect(pageCount(tester), 6);

    await tapPage(tester, 3);
    await tester.tap(find.text('Rotate'));
    await settle(tester);
    // Thumbnails don't render without the plugin: check the page list.
    final turned =
        tester.widget<DkPageGrid>(find.byType(DkPageGrid)).pageIds[2]
            as PageSource;
    expect(turned.addQuarterTurns, 1);

    final grid = tester.widget<DkPageGrid>(find.byType(DkPageGrid));
    final first = grid.pageIds.first;
    grid.onReorder!(0, 3);
    await tester.pump();
    expect(
      tester.widget<DkPageGrid>(find.byType(DkPageGrid)).pageIds[3],
      same(first),
    );
    expect(drops, 1);
  });

  testWidgets('+ inserts a blank page at the end (DK-0332)', (tester) async {
    await pumpP1(tester);
    await tester.tap(find.byTooltip('Insert pages'));
    await settle(tester);
    expect(find.text('From another PDF'), findsOneWidget);
    await tester.tap(find.text('Blank page'));
    for (var i = 0; i < 3; i++) {
      await settle(tester); // the neighbour's size, then the blank page
    }
    expect(tester.takeException(), isNull);
    expect(pageCount(tester), 6);
    expect(find.text('6 pages'), findsOneWidget);
  });

  testWidgets('Save keeps a copy next to the original, which stays as it '
      'was; Extract saves the selected pages', (tester) async {
    await pumpP1(tester);
    final before = await tester.runAsync(original.readAsBytes);
    await tapPage(tester, 2);
    await tapPage(tester, 3);
    await tester.tap(find.text('Extract'));
    for (var i = 0; i < 3; i++) {
      await settle(tester); // PDFium writes it, then reads it back
    }
    final extracted = File(
      '${store.userFolder.path}${sep}Taxes${sep}Five – extracted.pdf',
    );
    expect(extracted.existsSync(), isTrue);
    expect(
      (await tester.runAsync(() => PdfEngine.inspect(extracted.path)))!
          .pageCount,
      2,
    );

    // The two pages are still selected: delete them, then save.
    await tester.tap(find.text('Delete'));
    await settle(tester);
    await tester.tap(find.text('Save'));
    for (var i = 0; i < 3; i++) {
      await settle(tester);
    }
    final copy = File('${store.userFolder.path}${sep}Taxes${sep}Five (2).pdf');
    expect(copy.existsSync(), isTrue);
    expect(
      (await tester.runAsync(() => PdfEngine.inspect(copy.path)))!.pageCount,
      3,
    );
    final after = await tester.runAsync(original.readAsBytes);
    expect(after, before, reason: 'the original is never touched');
    expect(find.text('Viewer'), findsOneWidget, reason: 'P1 closed');
  });

  testWidgets('Cancel with changes asks first', (tester) async {
    await pumpP1(tester);
    await tapPage(tester, 1);
    await tester.tap(find.text('Duplicate'));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Discard'), findsOneWidget);
  });
}

/// PDFium and the file system between frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}
