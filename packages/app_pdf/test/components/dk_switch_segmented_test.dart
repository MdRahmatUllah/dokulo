import 'package:app_pdf/components/dk_segmented.dart';
import 'package:app_pdf/components/dk_switch.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/catalogue/switch_segmented_states.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(
  Widget child, {
  DkTokens? tokens,
  double scale = 1,
  Locale locale = const Locale('en'),
  TargetPlatform? platform,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light).copyWith(platform: platform),
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

const modes = [(0, 'Ranges'), (1, 'Every N'), (2, 'Each')];

void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final (lang, scale) in [('en', 1.0), ('en', 2.0), ('de', 2.0)]) {
      final name = '${theme}_${lang}_${(scale * 100).round()}';
      testWidgets('golden: $name', (tester) async {
        tester.view.physicalSize = Size(393, scale > 1 ? 600 : 360);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            const SingleChildScrollView(child: DkSwitchSegmentedGallery()),
            tokens: tokens,
            scale: scale,
            locale: Locale(lang),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/dk_switch_segmented_$name.png'),
        );
      });
    }
  }

  testWidgets('DkSwitch: Material 3 on Android, Cupertino on iOS, primary', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        DkSwitch(value: true, onChanged: (_) {}),
        platform: TargetPlatform.android,
      ),
    );
    expect(
      tester.widget<Switch>(find.byType(Switch)).activeTrackColor,
      DkTokens.light.color.primary,
    );
    await tester.pumpWidget(
      app(
        DkSwitch(value: true, onChanged: (_) {}),
        platform: TargetPlatform.iOS,
      ),
    );
    await tester.pumpAndSettle(); // the theme change animates
    expect(find.byType(CupertinoSwitch), findsOneWidget);
    expect(
      tester
          .widget<CupertinoSwitch>(find.byType(CupertinoSwitch))
          .activeTrackColor,
      DkTokens.light.color.primary,
    );
  });

  group('DkSegmented (DK-0130)', () {
    testWidgets('36 tall; the selected segment is surface with raised '
        'elevation; a tap picks', (tester) async {
      int? picked;
      await tester.pumpWidget(
        app(
          DkSegmented<int>(
            segments: modes,
            selected: 1,
            onChanged: (v) => picked = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(DkSegmented<int>)).height, 36);
      final selected = tester.widget<AnimatedContainer>(
        find.ancestor(
          of: find.text('Every N'),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final d = selected.decoration! as BoxDecoration;
      expect(d.color, DkTokens.light.color.surface);
      expect(d.boxShadow, DkTokens.light.elevation.raised);
      await tester.tap(find.text('Each'));
      expect(picked, 2);
    });

    testWidgets('semantics: a selected button in an exclusive group', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(DkSegmented<int>(segments: modes, selected: 1, onChanged: (_) {})),
      );
      expect(
        tester.getSemantics(find.text('Every N')),
        matchesSemantics(
          label: 'Every N',
          isButton: true,
          isInMutuallyExclusiveGroup: true,
          hasSelectedState: true,
          isSelected: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('a radio list at 160 % text where asked', (tester) async {
      int? picked;
      Widget seg(double scale) => app(
        DkSegmented<int>(
          segments: modes,
          selected: 0,
          onChanged: (v) => picked = v,
          radioAtLargeText: true,
        ),
        scale: scale,
      );
      await tester.pumpWidget(seg(1.3));
      expect(find.byType(Radio<int>), findsNothing);
      await tester.pumpWidget(seg(1.6));
      expect(find.byType(Radio<int>), findsNWidgets(3));
      await tester.tap(find.text('Each'));
      expect(picked, 2, reason: 'the whole row selects');
    });
  });
}
