import 'dart:typed_data';

import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/photo_finder/photo_finder.dart';
import 'package:app_pdf/photo_finder/photo_finder_screens.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A photo of paper on a desk.
final _jpeg = Uint8List.fromList(
  img.encodeJpg(
    img.fillRect(
      img.Image(width: 60, height: 60)..clear(img.ColorRgb8(150, 140, 120)),
      x1: 14,
      y1: 8,
      x2: 46,
      y2: 52,
      color: img.ColorRgb8(240, 238, 230),
    ),
  ),
);

class FakeLibrary implements PhotoLibrary {
  FakeLibrary(this.photos);
  final List<LibraryPhoto> photos;
  @override
  Future<bool> requestAccess() async => true;
  @override
  Future<int> count() async => photos.length;
  @override
  Future<List<LibraryPhoto>> range(int start, int end) async =>
      photos.sublist(start, end);
  @override
  Future<Uint8List?> thumbnail(String id, {int size = 320}) async => _jpeg;
}

void main() {
  late DokuloDatabase db;
  late ProviderContainer container;
  late List<(List<String>, PhotoConvertOptions)> converted;

  Future<void> pump(
    WidgetTester tester, {
    List<LibraryPhoto> photos = const [],
    DkTokens? tokens,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    db = DokuloDatabase.memory();
    addTearDown(db.close);
    converted = [];
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        photoLibraryProvider.overrideWithValue(FakeLibrary(photos)),
        documentScorerProvider.overrideWithValue((_) async => 0.9),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(
      () => container.read(photoFinderProvider.notifier).scan(),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dokuloTheme(tokens ?? DkTokens.light),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PhotoFinderScreen(
            onConvert: (ids, o) => converted.add((ids, o)),
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await tester.pumpAndSettle();
  }

  final photos = [
    (id: 'a', modified: DateTime(2026, 10, 5)),
    (id: 'b', modified: DateTime(2026, 10, 2)),
    (id: 'c', modified: DateTime(2026, 9, 20)),
  ];

  testWidgets('month headers over a 3-column grid', (tester) async {
    await pump(tester, photos: photos);
    expect(find.text('Documents in photos'), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget);
  });

  testWidgets('Select, pick two, Convert 2 to PDF, the options', (
    tester,
  ) async {
    await pump(tester, photos: photos);
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Photo of a document').at(0));
    await tester.tap(find.bySemanticsLabel('Photo of a document').at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Convert 2 to PDF'));
    await tester.pumpAndSettle();
    expect(find.text('Convert 2 photos'), findsOneWidget);
    await tester.tap(find.text('One PDF per photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create 2 PDFs'));
    await tester.pumpAndSettle();
    expect(converted.single.$1, ['a', 'c']);
    expect(converted.single.$2, (onePdf: false, cleanUp: true));
  });

  testWidgets('a long press: Not a document removes it for good', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, photos: photos);
    await tester.longPress(find.bySemanticsLabel('Photo of a document').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not a document'));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect([
      for (final p in container.read(photoFinderProvider).found) p.id,
    ], unorderedEquals(['b', 'c']));
    semantics.dispose();
  });

  testWidgets('nothing found: the empty state with Close', (tester) async {
    await pump(tester);
    expect(find.text('No documents found in your photos.'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Select'), findsNothing);
  });

  for (final (name, tokens, locale) in [
    ('light', DkTokens.light, const Locale('en')),
    ('dark', DkTokens.dark, const Locale('en')),
    ('de', DkTokens.light, const Locale('de')),
  ]) {
    testWidgets('golden: results selecting ($name)', (tester) async {
      await pump(tester, photos: photos, tokens: tokens, locale: locale);
      await tester.tap(find.text(name == 'de' ? 'Auswählen' : 'Select'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.bySemanticsLabel(RegExp('Dokument|document')).first,
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(PhotoFinderScreen),
        matchesGoldenFile('goldens/photo_finder_results_$name.png'),
      );
    });
  }

  testWidgets('the intro: Allow photo access says yes, Not now no', (
    tester,
  ) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        theme: dokuloTheme(DkTokens.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => answer = await showPhotoFinderIntro(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Find documents in your photos'), findsOneWidget);
    await tester.tap(find.text('Allow photo access'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(answer, isFalse);
  });

  testWidgets('the Home card shows only while a scan runs', (tester) async {
    final c = ProviderContainer(
      overrides: [photoFinderProvider.overrideWith(_Running.new)],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: dokuloTheme(DkTokens.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: PhotoFinderCard()),
        ),
      ),
    );
    expect(find.text('Looking through photos'), findsOneWidget);
    expect(
      find.text('1,240 of 5,800 · you can leave this screen'),
      findsOneWidget,
    );
  });
}

class _Running extends PhotoFinder {
  @override
  PhotoFinderState build() =>
      const PhotoFinderState(scanned: 1240, total: 5800, running: true);
}
