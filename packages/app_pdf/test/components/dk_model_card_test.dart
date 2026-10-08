import 'package:app_pdf/catalogue/model_card_states.dart';
import 'package:app_pdf/components/dk_button.dart';
import 'package:app_pdf/components/dk_model_card.dart';
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

DkModelCard card(DkModelState state, {VoidCallback? onLicence}) => DkModelCard(
  name: 'Gemma',
  quality: 'Fast',
  role: 'Summaries and questions',
  facts: '1.3 GB · needs 3 GB memory',
  licence: 'Apache-2.0',
  onLicence: onLicence ?? () {},
  state: state,
);

void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final (lang, scale) in [('en', 1.0), ('en', 2.0), ('de', 2.0)]) {
      final name = '${theme}_${lang}_${(scale * 100).round()}';
      testWidgets('golden: $name', (tester) async {
        tester.view.physicalSize = Size(393, scale > 1 ? 1800 : 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            const SingleChildScrollView(child: DkModelCardGallery()),
            tokens: tokens,
            scale: scale,
            locale: Locale(lang),
          ),
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/model_card_$name.png'),
        );
      });
    }
  }

  testWidgets('available: a secondary compact Download', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      app(card(DkModelAvailable(onDownload: () => taps++))),
    );
    final button = tester.widget<DkButton>(find.byType(DkButton));
    expect(
      (button.variant, button.size),
      (DkButtonVariant.secondary, DkButtonSize.compact),
    );
    await tester.tap(find.text('Download'));
    expect(taps, 1);
  });

  testWidgets('downloading: the ring with %, the bar and the detail; '
      'pause says the progress', (tester) async {
    final handle = tester.ensureSemantics();
    var paused = 0;
    await tester.pumpWidget(
      app(
        card(
          DkModelDownloading(
            progress: 0.32,
            detail: '420 MB of 1.3 GB · Wi-Fi',
            onPause: () => paused++,
          ),
        ),
        locale: const Locale('de'),
      ),
    );
    expect(find.text('32 %'), findsOneWidget);
    expect(find.text('420 MB of 1.3 GB · Wi-Fi'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.32,
    );
    await tester.tap(find.bySemanticsLabel('Pausieren, 32 %'));
    expect(paused, 1);
    handle.dispose();
  });

  testWidgets('installed: Delete in danger; unavailable: the text', (
    tester,
  ) async {
    await tester.pumpWidget(app(card(DkModelInstalled(onDelete: () {}))));
    expect(
      tester.widget<DkButton>(find.byType(DkButton)).variant,
      DkButtonVariant.tertiaryDanger,
    );
    expect(
      tester.widget<Text>(find.text('Delete')).style!.color,
      DkTokens.light.color.danger,
    );
    await tester.pumpWidget(app(card(const DkModelUnavailable())));
    expect(find.text('Not available on this phone'), findsOneWidget);
    expect(find.byType(DkButton), findsNothing);
  });

  testWidgets('the licence is a link', (tester) async {
    final handle = tester.ensureSemantics();
    var opened = 0;
    await tester.pumpWidget(
      app(card(const DkModelUnavailable(), onLicence: () => opened++)),
    );
    await tester.tap(find.text('Apache-2.0'));
    expect(opened, 1);
    expect(
      tester.getSemantics(find.text('Apache-2.0')),
      isSemantics(label: 'Apache-2.0', isLink: true, hasTapAction: true),
    );
    handle.dispose();
  });
}
