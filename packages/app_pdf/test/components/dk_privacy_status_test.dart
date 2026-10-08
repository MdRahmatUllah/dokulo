import 'package:app_pdf/catalogue/privacy_status_states.dart';
import 'package:app_pdf/components/dk_privacy_line.dart';
import 'package:app_pdf/components/dk_status_dot.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:app_pdf/theme/haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The haptics the components asked for.
final played = <String>[];

Widget app(
  Widget child, {
  DkTokens? tokens,
  double scale = 1,
  Locale locale = const Locale('en'),
  bool reduce = false,
}) => ProviderScope(
  overrides: [
    hapticsProvider.overrideWithValue(
      DkHaptics(
        selection: () async => played.add('selection'),
        light: () async => played.add('light'),
        medium: () async => played.add('medium'),
      ),
    ),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dokuloTheme(tokens ?? DkTokens.light),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        disableAnimations: reduce,
      ),
      child: app!,
    ),
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

void main() {
  setUp(played.clear);

  for (final (name, gallery, height) in [
    ('privacy_status', const DkPrivacyStatusGallery(), 200.0),
  ]) {
    for (final (theme, tokens) in [
      ('light', DkTokens.light),
      ('dark', DkTokens.dark),
    ]) {
      for (final (lang, scale) in [('en', 1.0), ('en', 2.0), ('de', 2.0)]) {
        final file = '${name}_${theme}_${lang}_${(scale * 100).round()}';
        testWidgets('golden: $file', (tester) async {
          tester.view.physicalSize = Size(393, height * (scale > 1 ? 1.8 : 1));
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            app(
              gallery,
              tokens: tokens,
              scale: scale,
              locale: Locale(lang),
              reduce: true, // the running dot holds still for the golden
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile('goldens/$file.png'),
          );
        });
      }
    }
  }

  group('DkPrivacyLine and DkStatusDot (DK-0110, DK-0112)', () {
    testWidgets('privacy: tool and Home wording', (tester) async {
      await tester.pumpWidget(
        app(
          const Column(
            children: [
              DkPrivacyLine(),
              DkPrivacyLine(where: DkPrivacyContext.home),
            ],
          ),
        ),
      );
      expect(find.text('Processed on this phone'), findsOneWidget);
      expect(find.text('Everything stays on this phone'), findsOneWidget);
    });

    testWidgets('status: 8 dp; running pulses, steady with Reduce Motion', (
      tester,
    ) async {
      double opacity() => tester
          .widget<FadeTransition>(
            find.descendant(
              of: find.byType(DkStatusDot),
              matching: find.byType(FadeTransition),
            ),
          )
          .opacity
          .value;
      await tester.pumpWidget(
        app(const Center(child: DkStatusDot(DkStatus.running))),
      );
      expect(
        tester.getSize(
          find.descendant(
            of: find.byType(DkStatusDot),
            matching: find.byType(Container),
          ),
        ),
        const Size(8, 8),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(opacity(), closeTo(0.35, 0.05));
      expect(find.bySemanticsLabel('Working'), findsOneWidget);

      await tester.pumpWidget(
        app(const Center(child: DkStatusDot(DkStatus.running)), reduce: true),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(opacity(), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
