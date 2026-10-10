import 'dart:io';

import 'package:app_pdf/components/dk_page_grid.dart';
import 'package:app_pdf/components/dk_page_thumb.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/providers/file_providers.dart';
import 'package:app_pdf/screens/p1_organize/organize_screen.dart';
import 'package:app_pdf/screens/t2_tool/tool_options_providers.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:app_pdf/theme/haptics.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
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
  var photosPicked = const <String>[];

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

  Future<void> pumpP1(
    WidgetTester tester, {
    DkTokens? tokens,
    int pages = 5,
    Size size = const Size(393, 852),
    List<String> photos = const [],
  }) async {
    // A phone: three columns, so the 5 pages fit on screen.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final id = (await tester.runAsync(() async {
      original = File('${store.userFolder.path}${sep}Taxes${sep}Five.pdf')
        ..parent.createSync(recursive: true);
      if (pages == 300) {
        await File(fixture('long-300-pages.pdf')).copy(original.path);
      } else {
        await PdfEngine.assemble([
          for (var i = 0; i < pages; i++)
            PageSource(fixture('long-300-pages.pdf'), i),
        ], original.path);
      }
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
          devicePickerProvider.overrideWithValue(
            (input, {required photos}) async => photos ? photosPicked : [],
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
    photosPicked = photos;
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

  // DK-0799: organize-drag, page 5 lifted and held between 8 and 9.
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('golden: organize_drag_$theme', (tester) async {
      await pumpP1(tester, tokens: tokens, pages: 12);
      Finder page(int n) =>
          find.byWidgetPredicate((w) => w is DkPageThumb && w.pageNumber == n);
      final from = tester.getCenter(page(5));
      final eight = tester.getRect(page(8));
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 600)); // long-press
      await gesture.moveTo(eight.centerRight + const Offset(4, 0));
      await tester.pump(const Duration(milliseconds: 300));
      // The lifted page floats in the navigator's overlay.
      await expectLater(
        find.byType(Navigator).first,
        matchesGoldenFile('goldens/organize_drag_$theme.png'),
      );
      expect(find.text('12 pages'), findsOneWidget, reason: 'not selecting');
      await gesture.up();
      await settle(tester);
    });
  }

  // DK-0800..DK-0803: the frames' states, side by side in docs/qa/organize/.
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    Finder page(int n) =>
        find.byWidgetPredicate((w) => w is DkPageThumb && w.pageNumber == n);

    testWidgets('golden: organize_selected_$theme', (tester) async {
      await pumpP1(tester, tokens: tokens, pages: 12);
      for (final n in [3, 6, 7]) {
        await tester.tap(page(n));
        await tester.pump();
      }
      await settle(tester); // the + leaves as the selection bar comes
      expect(find.text('3 selected'), findsOneWidget);
      await expectLater(
        find.byType(Navigator).first,
        matchesGoldenFile('goldens/organize_selected_$theme.png'),
      );
    });

    testWidgets('golden: organize_insert_$theme', (tester) async {
      await pumpP1(tester, tokens: tokens, pages: 12);
      await tester.tap(page(4));
      await tester.tap(find.byTooltip('Insert pages'));
      await settle(tester);
      await expectLater(
        find.byType(Navigator).first,
        matchesGoldenFile('goldens/organize_insert_$theme.png'),
      );
    });

    testWidgets('golden: organize_deleted_$theme', (tester) async {
      await pumpP1(tester, tokens: tokens, pages: 12);
      await tester.tap(page(5));
      await tester.tap(page(6));
      await tester.pump();
      await tester.tap(find.text('Delete'));
      await settle(tester);
      expect(find.text('2 pages deleted'), findsOneWidget);
      await expectLater(
        find.byType(Navigator).first,
        matchesGoldenFile('goldens/organize_deleted_$theme.png'),
      );
    });

    testWidgets('golden: organize_pinch_$theme', (tester) async {
      await pumpP1(tester, tokens: tokens, pages: 30);
      const centre = Offset(196, 300);
      final a = await tester.startGesture(centre - const Offset(100, 0));
      final b = await tester.startGesture(centre + const Offset(100, 0));
      for (var i = 1; i <= 10; i++) {
        final d = 200 - 80 * i / 10;
        await a.moveTo(centre - Offset(d / 2, 0));
        await b.moveTo(centre + Offset(d / 2, 0));
        await tester.pump();
      }
      await a.up();
      await b.up();
      await settle(tester);
      await expectLater(
        find.byType(Navigator).first,
        matchesGoldenFile('goldens/organize_pinch_$theme.png'),
      );
    });
  }

  testWidgets('Insert › From photos: each photo a page, after the selected '
      'one (DK-0801)', (tester) async {
    final dir = Directory.systemTemp.createTempSync('dk_p1_photos_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final photos = [
      for (final (i, w) in [300, 400].indexed)
        (File('${dir.path}${sep}photo$i.jpg')..writeAsBytesSync(
              img.encodeJpg(img.Image(width: w, height: 200)),
            ))
            .path,
    ];
    await pumpP1(tester, photos: photos);
    await tapPage(tester, 2);
    await tester.tap(find.byTooltip('Insert pages'));
    await settle(tester);
    await tester.tap(find.text('From photos'));
    await settleUntil(tester, () => pageCount(tester) == 7);
    expect(pageCount(tester), 7);
    final ids = tester.widget<DkPageGrid>(find.byType(DkPageGrid)).pageIds;
    expect(
      [for (final id in ids) (id as PageSource).path.endsWith('photos.pdf')],
      [false, false, true, true, false, false, false],
    );
  });

  testWidgets('+ inserts a blank page at the end (DK-0332)', (tester) async {
    await pumpP1(tester);
    await tester.tap(find.byTooltip('Insert pages'));
    await settle(tester);
    expect(find.text('From another PDF'), findsOneWidget);
    await tester.tap(find.text('Blank page'));
    // The neighbour's size, then the blank page.
    await settleUntil(tester, () => pageCount(tester) == 6);
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
    final extracted = File(
      '${store.userFolder.path}${sep}Taxes${sep}Five – extracted.pdf',
    );
    // PDFium writes it, then reads it back for the index.
    await settleUntil(tester, extracted.existsSync);
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
    await settleUntil(tester, () => find.text('Viewer').evaluate().isNotEmpty);
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

  double thumbWidth(WidgetTester tester) =>
      tester.getSize(find.byType(DkPageThumb).first).width;

  testWidgets('pinch: bigger or smaller pages, 2 to 6 columns (DK-0334)', (
    tester,
  ) async {
    await pumpP1(tester);
    final three = thumbWidth(tester);
    Future<void> pinch(double from, double to) async {
      const centre = Offset(196, 300);
      final a = await tester.startGesture(centre - Offset(from / 2, 0));
      final b = await tester.startGesture(centre + Offset(from / 2, 0));
      for (var i = 1; i <= 10; i++) {
        final d = from + (to - from) * i / 10;
        await a.moveTo(centre - Offset(d / 2, 0));
        await b.moveTo(centre + Offset(d / 2, 0));
        await tester.pump();
      }
      await a.up();
      await b.up();
      await settle(tester);
    }

    await pinch(100, 140); // out: 2 columns, bigger
    expect(thumbWidth(tester), greaterThan(three));
    await pinch(200, 50); // in: down to 6 columns, smaller
    expect(thumbWidth(tester), lessThan(three));
  });

  testWidgets('a tablet starts at 5 columns', (tester) async {
    await pumpP1(tester, size: const Size(700, 1000));
    expect(
      tester.widget<DkPageGrid>(find.byType(DkPageGrid)).initialColumns,
      5,
    );
  });

  testWidgets('300 pages: only the visible ones are built, as skeletons '
      'with their numbers until they render (DK-0335)', (tester) async {
    await pumpP1(tester, pages: 300);
    expect(find.text('300 pages'), findsOneWidget);
    final built = find.byType(DkPageThumb).evaluate().length;
    expect(built, lessThan(40), reason: 'virtualised');
    // No thumbnail renders in a test: every page is its skeleton + number.
    final thumbs = tester.widgetList<DkPageThumb>(find.byType(DkPageThumb));
    expect(thumbs.every((t) => t.page == null), isTrue);
    expect(find.text('1'), findsWidgets); // on the skeleton and under it

    await tester.drag(find.byType(DkPageGrid), const Offset(0, -60000));
    await settle(tester);
    expect(find.text('300'), findsWidgets);
  });
}

/// Frames and real time until [done] (PDFium and the disk are slower when
/// the gate runs four suites at once), at most 15 s.
Future<void> settleUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await settle(tester);
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
