import 'dart:typed_data';

import 'package:app_pdf/components/dk_page_thumb.dart';
import 'package:app_pdf/components/dk_text_action.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/screens/s1_scanner/scan_session.dart';
import 'package:app_pdf/screens/s1_scanner/scanner_settings.dart';
import 'package:app_pdf/screens/s2_review/s2_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A page photo: paper with a dark band whose height tells pages apart.
Uint8List photo(int n) {
  final im = img.Image(width: 60, height: 80)
    ..clear(img.ColorRgb8(240, 238, 230));
  img.fillRect(
    im,
    x1: 8,
    y1: 10,
    x2: 52,
    y2: 10 + 6 * n,
    color: img.ColorRgb8(60, 60, 60),
  );
  return Uint8List.fromList(img.encodeJpg(im));
}

void main() {
  late ProviderContainer container;
  late MemoryScanStore store;
  late MemoryPrefsStore prefs;
  var added = 0;
  int? retook;

  List<ScannedPage> pages() => container.read(scanSessionProvider);

  Future<void> pump(
    WidgetTester tester, {
    int count = 3,
    DkTokens? tokens,
    Locale locale = const Locale('en'),
    bool withSave = true,
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    added = 0;
    retook = null;
    store = MemoryScanStore();
    container = ProviderContainer(
      overrides: [
        scanStoreProvider.overrideWithValue(store),
        scannerPrefsStoreProvider.overrideWithValue(prefs = MemoryPrefsStore()),
      ],
    );
    addTearDown(container.dispose);
    for (var i = 1; i <= count; i++) {
      await container.read(scanSessionProvider.notifier).add(photo(i));
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dokuloTheme(tokens ?? DkTokens.light),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: S2Screen(
            onAddPages: () => added++,
            onSave: withSave ? () {} : null,
            onRetake: (i) => retook = i,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the title, "1 of 3"; a swipe goes to the next page', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Review 3 pages'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('2 of 3'), findsOneWidget);
  });

  testWidgets('Rotate turns the current page', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Rotate'));
    await tester.pump();
    expect(pages().first.turns, 1);
  });

  testWidgets('Delete takes the page out, with Undo putting it back', (
    tester,
  ) async {
    await pump(tester);
    final first = pages().first.id;
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(pages(), hasLength(2));
    expect(find.text('Page deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(pages().first.id, first);
  });

  testWidgets('deleting the last page goes back to the camera', (tester) async {
    await pump(tester, count: 1);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(added, 1);
  });

  testWidgets(
    'the tray: a tap goes to the page; Retake names it; + adds pages',
    (tester) async {
      await pump(tester);
      await tester.tap(find.byType(DkPageThumb).at(2));
      await tester.pumpAndSettle();
      expect(find.text('3 of 3'), findsOneWidget);
      await tester.tap(find.text('Retake'));
      expect(retook, 2);
      await tester.tap(find.text('Add pages'));
      expect(added, 1);
    },
  );

  testWidgets('Save is disabled until the Save sheet is there', (tester) async {
    await pump(tester, withSave: false);
    final save = tester.widget<DkTextAction>(
      find.widgetWithText(DkTextAction, 'Save'),
    );
    expect(save.onTap, isNull);
  });

  testWidgets('an unsaved scan comes back after a kill', (tester) async {
    await pump(tester);
    final manifest = store.manifest;
    // A new process: the session is empty, the store still has the scan.
    final again = ProviderContainer(
      overrides: [scanStoreProvider.overrideWithValue(store)],
    );
    addTearDown(again.dispose);
    expect(again.read(scanSessionProvider), isEmpty);
    await again.read(scanSessionProvider.notifier).restore();
    expect(again.read(scanSessionProvider), hasLength(3));
    expect(store.manifest, manifest);
  });

  testWidgets('Crop: Full page, Apply, then the chip crops every page', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Crop'));
    await tester.pumpAndSettle();
    // Crop mode: the overlay and Cancel / Apply instead of the edit row.
    expect(find.text('Rotate'), findsNothing);
    expect(find.text('Auto'), findsNothing, reason: 'nothing was detected');
    await tester.tap(find.text('Full page'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(pages().first.crop, ScannedPage.fullPage);
    expect(pages()[1].crop, isNull);
    await tester.tap(find.text('Apply to all pages'));
    await tester.pumpAndSettle();
    expect(pages().map((p) => p.crop), everyElement(ScannedPage.fullPage));
    expect(find.text('Apply to all pages'), findsNothing);
  });

  testWidgets('Crop: Cancel keeps the page as it was', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Crop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Full page'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(pages().first.crop, isNull);
    expect(find.text('Rotate'), findsOneWidget);
  });

  testWidgets('a rotation offers the chip; it turns every page alike', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Rotate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply to all pages'));
    await tester.pumpAndSettle();
    expect(pages().map((p) => p.turns), everyElement(1));
  });

  testWidgets('Filter: a filter for this page, then for all with Undo', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    expect(find.text('Brightness'), findsOneWidget);
    await tester.tap(find.text('Greyscale'));
    await tester.pumpAndSettle();
    expect(pages().first.filter, ScanFilterChoice.greyscale);
    expect(pages()[1].filter, isNull);
    await tester.tap(find.text('Apply to all pages'));
    await tester.pumpAndSettle();
    expect(
      pages().map((p) => p.filter),
      everyElement(ScanFilterChoice.greyscale),
    );
    expect(find.text('Applied to all pages'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(pages()[1].filter, isNull);
    expect(pages().first.filter, ScanFilterChoice.greyscale);
  });

  testWidgets('Filter: Use as default, and a long press does the same', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Black & white'));
    await tester.tap(find.text('Black & white'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use as default'));
    await tester.pumpAndSettle();
    expect(
      container.read(scannerSettingsProvider).filter,
      ScanFilterChoice.blackWhite,
    );
    expect(prefs.json, contains('blackWhite'));
    await tester.ensureVisible(find.text('Original'));
    await tester.longPress(find.text('Original'));
    await tester.pumpAndSettle();
    expect(
      container.read(scannerSettingsProvider).filter,
      ScanFilterChoice.original,
    );
  });

  test('the preview matrix: Original is the identity', () {
    expect(
      scanPreviewFilter(ScanFilterChoice.original),
      const ColorFilter.matrix([
        1, 0, 0, 0, 0, //
        0, 1, 0, 0, 0, //
        0, 0, 1, 0, 0, //
        0, 0, 0, 1, 0, //
      ]),
    );
  });

  test('a page keeps its crop through the manifest', () {
    const page = ScannedPage(
      'a',
      '/a.jpg',
      quad: [Offset(.1, .1), Offset(.9, .1), Offset(.9, .9), Offset(.1, .9)],
      crop: ScannedPage.fullPage,
      turns: 2,
    );
    final back = ScannedPage.fromJson(page.toJson());
    expect(back.quad, page.quad);
    expect(back.crop, page.crop);
    expect(back.turns, 2);
    expect(back.corners, ScannedPage.fullPage);
  });

  for (final (name, tokens, locale) in [
    ('light', DkTokens.light, const Locale('en')),
    ('dark', DkTokens.dark, const Locale('en')),
    ('de', DkTokens.light, const Locale('de')),
  ]) {
    testWidgets('golden: review ($name)', (tester) async {
      await pump(tester, count: 6, tokens: tokens, locale: locale);
      await tester.runAsync(() async {
        for (final e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(S2Screen),
        matchesGoldenFile('goldens/s2_review_$name.png'),
      );
    });

    testWidgets('golden: crop ($name)', (tester) async {
      await pump(tester, count: 6, tokens: tokens, locale: locale);
      await tester.tap(find.text(name == 'de' ? 'Zuschneiden' : 'Crop'));
      await tester.runAsync(() async {
        for (final e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(S2Screen),
        matchesGoldenFile('goldens/s2_crop_$name.png'),
      );
    });

    testWidgets('golden: filter ($name)', (tester) async {
      await pump(tester, count: 6, tokens: tokens, locale: locale);
      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name == 'de' ? 'Graustufen' : 'Greyscale'));
      await tester.runAsync(() async {
        for (final e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(S2Screen),
        matchesGoldenFile('goldens/s2_filter_$name.png'),
      );
    });
  }
}
