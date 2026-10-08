import 'package:app_pdf/catalogue/bar_states.dart';
import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/components/dk_top_bar.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(
  Widget home, {
  DkTokens? tokens,
  Locale locale = const Locale('en'),
  double textScale = 1,
  TargetPlatform platform = TargetPlatform.android,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light).copyWith(platform: platform),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery.withClampedTextScaling(
    minScaleFactor: textScale,
    maxScaleFactor: textScale,
    child: home,
  ),
);

void phone(WidgetTester tester, [Size size = const Size(393, 852)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final (lang, scale) in [('en', 1.0), ('en', 2.0), ('de', 2.0)]) {
      final file = 'top_bar_${name}_${lang}_${(scale * 100).round()}';
      testWidgets('every bar: $file', (tester) async {
        phone(tester, Size(393, scale == 1 ? 760 : 900));
        await tester.pumpWidget(
          app(
            const Scaffold(body: SingleChildScrollView(child: TopBarStates())),
            tokens: tokens,
            textScale: scale,
            locale: Locale(lang),
          ),
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(TopBarStates),
          matchesGoldenFile('goldens/$file.png'),
        );
      });
    }
  }

  testWidgets('56 tall; the title is left on Android and centred on iOS', (
    tester,
  ) async {
    phone(tester);
    for (final (platform, centred) in [
      (TargetPlatform.android, false),
      (TargetPlatform.iOS, true),
    ]) {
      await tester.pumpWidget(
        app(
          Scaffold(
            appBar: DkTopBar(
              title: 'Settings',
              actions: [
                DkTopBarAction(
                  icon: DkIcons.search,
                  tooltip: 'Search',
                  onPressed: () {},
                ),
              ],
            ),
          ),
          platform: platform,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(DkTopBar)).height, 56);
      final title = tester.getCenter(find.text('Settings')).dx;
      if (centred) {
        expect(title, closeTo(393 / 2, 1));
      } else {
        expect(title, lessThan(393 / 2));
      }
    }
  });

  testWidgets('back pops; the overflow is anchored to its button', (
    tester,
  ) async {
    phone(tester);
    BuildContext? anchored;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        theme: dokuloTheme(DkTokens.light),
        home: const Scaffold(body: Text('home')),
      ),
    );
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: DkTopBar(
            title: 'Viewer',
            onOverflow: (anchor) => anchored = anchor,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More'));
    expect(anchored, isNotNull);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('the hairline appears once content scrolls under', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      app(
        Scaffold(
          appBar: const DkTopBar(title: 'Files'),
          body: ListView(
            children: [for (var i = 0; i < 40; i++) Text('row $i')],
          ),
        ),
      ),
    );
    Color border() =>
        ((tester
                            .widget<DecoratedBox>(
                              find
                                  .descendant(
                                    of: find.byType(DkTopBar),
                                    matching: find.byType(DecoratedBox),
                                  )
                                  .first,
                            )
                            .decoration
                        as BoxDecoration)
                    .border!
                as Border)
            .bottom
            .color;
    expect(border(), DkTokens.light.color.surface);
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();
    expect(border(), DkTokens.light.color.outline);
  });

  testWidgets('editing: Cancel and Done, in EN and DE', (tester) async {
    phone(tester);
    for (final (locale, cancel, done) in [
      (const Locale('en'), 'Cancel', 'Done'),
      (const Locale('de'), 'Abbrechen', 'Fertig'),
    ]) {
      final taps = <String>[];
      await tester.pumpWidget(
        app(
          Scaffold(
            appBar: DkTopBar.editing(
              title: 'Editing',
              onCancel: () => taps.add('cancel'),
              onDone: () => taps.add('done'),
            ),
          ),
          locale: locale,
        ),
      );
      await tester.tap(find.text(cancel));
      await tester.tap(find.text(done));
      expect(taps, ['cancel', 'done']);
    }
  });

  testWidgets('large: 112 expanded, 56 collapsed; one title heading at a '
      'time', (tester) async {
    phone(tester);
    final handle = tester.ensureSemantics();
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: CustomScrollView(
            controller: scroll,
            slivers: [
              const DkLargeTopBar(title: 'Files'),
              SliverList.list(
                children: [for (var i = 0; i < 40; i++) Text('row $i')],
              ),
            ],
          ),
        ),
      ),
    );
    // A sliver has no box size: measure the header's content.
    final header = find.descendant(
      of: find.byType(DkLargeTopBar),
      matching: find.byType(Stack),
    );
    expect(tester.getSize(header.first).height, 112);
    expect(find.semantics.byLabel('Files'), findsOne);
    scroll.jumpTo(200);
    await tester.pump();
    expect(tester.getSize(header.first).height, 56);
    expect(find.semantics.byLabel('Files'), findsOne);
    handle.dispose();
  });

  testWidgets('editing at 200 %: Cancel and Done never overlap; the title '
      'sits between them', (tester) async {
    phone(tester);
    for (final (locale, cancel, done) in [
      (const Locale('en'), 'Cancel', 'Done'),
      (const Locale('de'), 'Abbrechen', 'Fertig'),
    ]) {
      await tester.pumpWidget(
        app(
          Scaffold(
            appBar: DkTopBar.editing(
              title: 'Edit',
              onCancel: () {},
              onDone: () {},
            ),
          ),
          locale: locale,
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      final left = tester.getRect(find.text(cancel));
      final right = tester.getRect(find.text(done));
      final title = tester.getRect(find.text('Edit'));
      expect(left.right, lessThanOrEqualTo(right.left));
      expect(title.left, greaterThanOrEqualTo(left.right));
      expect(title.right, lessThanOrEqualTo(right.left));
      // In EN it stays whole. (In DE the test font's 1 em glyphs leave it
      // no room; real fonts do.)
      if (locale.languageCode == 'en') expect(title.width, greaterThan(0));
      expect(tester.getSize(find.byType(DkTopBar)).height, 56);
    }
  });

  testWidgets('large, collapsed: a long title stops before the actions', (
    tester,
  ) async {
    phone(tester);
    final scroll = ScrollController(initialScrollOffset: 200);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: CustomScrollView(
            controller: scroll,
            slivers: [
              DkLargeTopBar(
                title: 'A very long title for a tab root',
                actions: TopBarStates.actions,
                onOverflow: (_) {},
              ),
              SliverList.list(
                children: [for (var i = 0; i < 40; i++) Text('row $i')],
              ),
            ],
          ),
        ),
      ),
    );
    final small = find.text('A very long title for a tab root').last;
    expect(
      tester.getRect(small).right,
      lessThanOrEqualTo(tester.getRect(find.byTooltip('Search')).left),
    );
  });

  testWidgets('targets and semantics: 48 dp, labelled buttons, a header', (
    tester,
  ) async {
    phone(tester);
    final handle = tester.ensureSemantics();
    for (final (bar, buttons) in <(PreferredSizeWidget, List<String>)>[
      (
        DkTopBar(
          title: 'Settings',
          actions: TopBarStates.actions,
          onOverflow: (_) {},
        ),
        ['Back', 'Search', 'Sort', 'More'],
      ),
      (
        const DkTopBar(title: 'Settings', leading: DkTopBarLeading.close),
        ['Close'],
      ),
      (
        DkTopBar.editing(title: 'Settings', onCancel: () {}, onDone: () {}),
        ['Cancel', 'Done'],
      ),
    ]) {
      await tester.pumpWidget(app(Scaffold(appBar: bar)));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(
        tester.getSemantics(find.text('Settings')),
        isSemantics(isHeader: true, label: 'Settings'),
      );
      for (final label in buttons) {
        expect(
          find.semantics.byPredicate(
            (n) =>
                n.label == label &&
                n.getSemanticsData().flagsCollection.isButton,
          ),
          findsOne,
          reason: label,
        );
      }
    }
    handle.dispose();
  });

  testWidgets('iOS with nothing on the left: the small bar and the large bar '
      'lay out, the title centred', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      app(
        const Scaffold(
          appBar: DkTopBar(title: 'Files', leading: DkTopBarLeading.none),
        ),
        platform: TargetPlatform.iOS,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getCenter(find.text('Files')).dx, closeTo(393 / 2, 1));
    final scroll = ScrollController(initialScrollOffset: 200);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: CustomScrollView(
            controller: scroll,
            slivers: [
              const DkLargeTopBar(title: 'Files'),
              SliverList.list(
                children: [for (var i = 0; i < 40; i++) Text('row $i')],
              ),
            ],
          ),
        ),
        platform: TargetPlatform.iOS,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getCenter(find.text('Files').last).dx, closeTo(393 / 2, 1));
  });
}
