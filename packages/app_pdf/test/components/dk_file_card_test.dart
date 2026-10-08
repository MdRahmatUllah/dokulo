import 'package:app_pdf/catalogue/file_card_states.dart';
import 'package:app_pdf/components/dk_file_card.dart';
import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(
  Widget child, {
  DkTokens? tokens,
  double scale = 1,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: app!,
  ),
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

const page = SizedBox(
  width: 60,
  height: 85,
  child: ColoredBox(color: Color(0xFFFFFFFF)),
);

void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final (lang, scale) in [('en', 1.0), ('en', 2.0), ('de', 2.0)]) {
      final name = '${theme}_${lang}_${(scale * 100).round()}';
      testWidgets('golden: $name', (tester) async {
        tester.view.physicalSize = Size(393, scale > 1 ? 2000 : 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            const SingleChildScrollView(child: DkFileCardGallery()),
            tokens: tokens,
            scale: scale,
            locale: Locale(lang),
          ),
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/file_card_$name.png'),
        );
      });
    }
  }

  testWidgets('list row: 72 dp, a 44 × 56 thumbnail, the name keeps ".pdf"', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        SizedBox(
          width: 300,
          child: DkFileCard(
            name: 'Mietvertrag_Musterstraße_12_2026_final_signed.pdf',
            meta: '2.4 MB · 12 pages',
            thumbnail: page,
            onTap: () {},
            onMore: () {},
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(DkFileCard)).height, 72);
    expect(
      tester.getSize(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 44 && w.height == 56,
        ),
      ),
      const Size(44, 56),
    );
    final shown = tester.widget<Text>(find.textContaining('…')).data!;
    expect(shown, endsWith('.pdf'));
  });

  testWidgets('multi-select: an empty circle, then a check; read as selected', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    Widget card(bool selected) => app(
      DkFileCard(
        name: 'Scan.pdf',
        meta: '1 page',
        thumbnail: page,
        onTap: () {},
        selected: selected,
      ),
    );
    await tester.pumpWidget(card(false));
    expect(find.byIcon(DkIcons.check), findsNothing);
    await tester.pumpWidget(card(true));
    expect(find.byIcon(DkIcons.check), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(DkFileCard)),
      isSemantics(
        label: 'Scan.pdf\n1 page',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('locked: blurred with a lock; encrypted: a lock after the meta; '
      'both said', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      app(
        Column(
          children: [
            DkFileCard(
              name: 'A.pdf',
              meta: 'm',
              thumbnail: page,
              onTap: () {},
              locked: true,
            ),
            DkFileCard(
              name: 'B.pdf',
              meta: 'm',
              thumbnail: page,
              onTap: () {},
              encrypted: true,
            ),
          ],
        ),
        locale: const Locale('de'),
      ),
    );
    expect(find.byType(ImageFiltered), findsOneWidget);
    expect(find.byIcon(DkIcons.lock), findsNWidgets(2));
    expect(find.bySemanticsLabel('A.pdf\nm\nGesperrt'), findsOneWidget);
    expect(
      find.bySemanticsLabel('B.pdf\nm\nPasswortgeschützt'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('loading: a skeleton; processing: the 2 dp line; HTML: a page '
      'with the web icon', (tester) async {
    await tester.pumpWidget(
      app(
        Column(
          children: [
            DkFileCard(name: 'A.pdf', meta: 'm', onTap: () {}, progress: 0.5),
            DkFileCard(
              name: 'B.html',
              meta: 'm',
              onTap: () {},
              kind: DkFileKind.html,
            ),
          ],
        ),
      ),
    );
    final line = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect((line.value, line.minHeight), (0.5, 2));
    expect(find.byIcon(DkIcons.language), findsOneWidget);
  });

  testWidgets('tap, long press and the more button', (tester) async {
    var taps = 0, holds = 0, menus = 0;
    await tester.pumpWidget(
      app(
        DkFileCard(
          name: 'A.pdf',
          meta: 'm',
          thumbnail: page,
          onTap: () => taps++,
          onLongPress: () => holds++,
          onMore: () => menus++,
        ),
      ),
    );
    await tester.tap(find.text('A.pdf'));
    await tester.longPress(find.text('A.pdf'));
    await tester.tap(
      find.byIcon(DkIcons.overflow(tester.element(find.byType(DkFileCard)))),
    );
    expect((taps, holds, menus), (1, 1, 1));
  });

  testWidgets('grid: the whole 48 dp More target is tappable', (tester) async {
    var menus = 0;
    await tester.pumpWidget(
      app(
        SizedBox(
          width: 160,
          child: DkFileCard(
            variant: DkFileCardVariant.grid,
            name: 'A.pdf',
            meta: 'm',
            thumbnail: page,
            onTap: () {},
            onMore: () => menus++,
          ),
        ),
      ),
    );
    final icon = find.byIcon(
      DkIcons.overflow(tester.element(find.byType(DkFileCard))),
    );
    final target = tester.getRect(
      find.ancestor(of: icon, matching: find.byType(Positioned)).first,
    );
    expect(target.shortestSide, greaterThanOrEqualTo(48));
    await tester.tapAt(target.topRight + const Offset(-1, 1));
    expect(menus, 1);
  });
}
