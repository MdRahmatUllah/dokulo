import 'package:app_pdf/catalogue/promo_card_states.dart';
import 'package:app_pdf/components/dk_button.dart';
import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/components/dk_promo_cards.dart';
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

void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final (lang, scale) in [('en', 1.0), ('en', 2.0), ('de', 2.0)]) {
      final name = '${theme}_${lang}_${(scale * 100).round()}';
      testWidgets('golden: $name', (tester) async {
        tester.view.physicalSize = Size(393, scale > 1 ? 1500 : 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            const SingleChildScrollView(child: DkPromoCardsGallery()),
            tokens: tokens,
            scale: scale,
            locale: Locale(lang),
          ),
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/promo_cards_$name.png'),
        );
      });
    }
  }

  testWidgets('DkContinueCard (DK-0096): primaryContainer at 60 %, the '
      'button and the ×', (tester) async {
    var go = 0, closed = 0;
    await tester.pumpWidget(
      app(
        DkContinueCard(
          icon: DkIcons.scan,
          title: 'Continue your scan',
          sub: '3 pages',
          action: 'Continue',
          onAction: () => go++,
          onDismiss: () => closed++,
        ),
      ),
    );
    final box =
        tester.widget<Container>(find.byType(Container).first).decoration!
            as BoxDecoration;
    expect(box.color!.a, closeTo(0.6, 0.01));
    expect(
      tester.widget<DkButton>(find.byType(DkButton)).size,
      DkButtonSize.compact,
    );
    await tester.tap(find.text('Continue'));
    await tester.tap(find.bySemanticsLabel('Close'));
    expect((go, closed), (1, 1));
  });

  group('DkProCard (DK-0098)', () {
    testWidgets('the copy in German, proContainer, "See Pro" opens the '
        'paywall', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        app(
          DkProCard(onOpen: () => opened++, onDismiss: () {}),
          locale: const Locale('de'),
        ),
      );
      expect(
        find.text('Alle Werkzeuge freischalten – für immer'),
        findsOneWidget,
      );
      final box =
          tester.widget<Container>(find.byType(Container).first).decoration!
              as BoxDecoration;
      expect(box.color, DkTokens.light.color.proContainer);
      await tester.tap(find.text('Pro ansehen'));
      expect(opened, 1);
      expect(find.bySemanticsLabel('Schließen'), findsOneWidget);
    });

    testWidgets('all of See Pro takes touches, its left edge too (DK-1074)', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(app(DkProCard(onOpen: () => opened++)));
      final button = tester.getRect(find.byType(DkButton));
      await tester.tapAt(button.centerLeft + const Offset(2, 0));
      expect(opened, 1);
    });

    testWidgets('on Me: no ×', (tester) async {
      await tester.pumpWidget(app(DkProCard(onOpen: () {})));
      expect(find.bySemanticsLabel('Close'), findsNothing);
      expect(tester.hasRunningAnimations, isFalse, reason: 'no animation');
    });
  });
}
