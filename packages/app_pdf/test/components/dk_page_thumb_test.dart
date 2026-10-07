import 'package:app_pdf/catalogue/page_thumb_states.dart';
import 'package:app_pdf/components/dk_page_thumb.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_layout.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
          app(const PageThumbStates(), tokens: tokens, textScale: scale),
        );
        await expectLater(
          find.byType(PageThumbStates),
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
              page: const CataloguePage(),
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
              page: const CataloguePage(),
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
            page: const CataloguePage(),
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
            child: DkPageThumb(
              pageNumber: 1,
              pageCount: 1,
              page: CataloguePage(),
            ),
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
