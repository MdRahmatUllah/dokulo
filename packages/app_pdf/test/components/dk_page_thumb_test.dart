import 'package:app_pdf/components/dk_page_thumb.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_layout.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A page as the design export draws it: a title bar and text lines. Not
/// symmetric, so a rotation shows.
class _Page extends StatelessWidget {
  const _Page();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 60,
    height: 80,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 26, height: 4, color: const Color(0xFF8E9AAD)),
          const SizedBox(height: 6),
          for (var i = 0; i < 9; i++) ...[
            Container(height: 1.5, color: const Color(0xFFD3D8E0)),
            const SizedBox(height: 3.5),
          ],
        ],
      ),
    ),
  );
}

Widget app(
  Widget child, {
  DkTokens? tokens,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery.withClampedTextScaling(
    minScaleFactor: textScale,
    maxScaleFactor: textScale,
    child: Scaffold(body: child),
  ),
);

/// Every state, as in the grid (3 columns) and the tray (56 × 72).
class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget cell(Widget thumb) => SizedBox(width: 96, child: thumb);
    return ColoredBox(
      color: t.color.background,
      child: Padding(
        padding: EdgeInsets.all(t.space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: t.space.m,
              runSpacing: t.space.l,
              children: [
                cell(
                  const DkPageThumb(
                    pageNumber: 1,
                    pageCount: 12,
                    page: _Page(),
                  ),
                ),
                cell(
                  const DkPageThumb(
                    pageNumber: 2,
                    pageCount: 12,
                    page: _Page(),
                    selected: true,
                  ),
                ),
                cell(const DkPageThumb(pageNumber: 3, pageCount: 12)),
                cell(
                  const DkPageThumb(
                    pageNumber: 4,
                    pageCount: 12,
                    page: _Page(),
                    quarterTurns: 1,
                  ),
                ),
              ],
            ),
            SizedBox(height: t.space.l),
            Row(
              children: [
                for (final (n, selected) in [(1, false), (2, true), (3, false)])
                  Padding(
                    padding: EdgeInsets.only(right: t.space.s),
                    child: SizedBox(
                      width: 56,
                      child: DkPageThumb(
                        pageNumber: n,
                        pageCount: 12,
                        page: const _Page(),
                        selected: selected,
                        aspectRatio: 56 / 72,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('every state, $name, ${(scale * 100).round()} %', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(460, 440);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(const _Gallery(), tokens: tokens, textScale: scale),
        );
        await expectLater(
          find.byType(_Gallery),
          matchesGoldenFile(
            'goldens/page_thumb_${name}_${(scale * 100).round()}.png',
          ),
        );
      });
    }
  }

  testWidgets('a screen reader hears "Page 3 of 12", selected, in EN and DE', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    for (final (locale, label) in [
      (const Locale('en'), 'Page 3 of 12'),
      (const Locale('de'), 'Seite 3 von 12'),
    ]) {
      await tester.pumpWidget(
        app(
          SizedBox(
            width: 96,
            child: DkPageThumb(
              pageNumber: 3,
              pageCount: 12,
              page: const _Page(),
              selected: true,
              onTap: () {},
            ),
          ),
          locale: locale,
        ),
      );
      expect(
        tester.getSemantics(find.byType(DkPageThumb)),
        isSemantics(
          label: label,
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
          hasLongPressAction: false,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
    }
    // The number below isn't read twice.
    expect(find.bySemanticsLabel('3'), findsNothing);
    handle.dispose();
  });

  testWidgets('tap, long press, and the tray size stays a 48 dp target', (
    tester,
  ) async {
    var taps = 0, presses = 0;
    await tester.pumpWidget(
      app(
        Center(
          child: SizedBox(
            width: 56,
            child: DkPageThumb(
              pageNumber: 1,
              pageCount: 2,
              page: const _Page(),
              aspectRatio: 56 / 72,
              onTap: () => taps++,
              onLongPress: () => presses++,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(DkPageThumb));
    await tester.longPress(find.byType(DkPageThumb));
    expect((taps, presses), (1, 1));
    final size = tester.getSize(find.byType(DkPageThumb));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('keyboard focus draws the 2 dp ring; pressed adds the overlay', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        SizedBox(
          width: 96,
          child: DkPageThumb(
            pageNumber: 1,
            pageCount: 2,
            page: const _Page(),
            onTap: () {},
          ),
        ),
      ),
    );
    Iterable<BoxDecoration> decorations() => tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>();
    final ring = DkTokens.light.selectionRing;
    bool hasRing() =>
        decorations().any((d) => d.border == Border.fromBorderSide(ring));
    expect(hasRing(), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(hasRing(), isTrue);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(DkPageThumb)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      decorations().any((d) => d.color == DkTokens.light.state.pressed),
      isTrue,
    );
    await gesture.up();
  });

  testWidgets('dark dims the page to 92 %; light leaves it white', (
    tester,
  ) async {
    for (final (tokens, factor) in [
      (DkTokens.light, 1.0),
      (DkTokens.dark, 0.92),
    ]) {
      await tester.pumpWidget(
        app(
          const SizedBox(
            width: 96,
            child: DkPageThumb(pageNumber: 1, pageCount: 1, page: _Page()),
          ),
          tokens: tokens,
        ),
      );
      await tester.pumpAndSettle(); // the theme change animates
      final filter = tester.widget<ColorFiltered>(find.byType(ColorFiltered));
      expect(
        filter.colorFilter,
        ColorFilter.matrix([
          factor, 0, 0, 0, 0, //
          0, factor, 0, 0, 0, //
          0, 0, factor, 0, 0, //
          0, 0, 0, 1, 0, //
        ]),
      );
    }
  });
}
