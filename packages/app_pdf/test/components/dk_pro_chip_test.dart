import 'package:app_pdf/catalogue/pro_chip_states.dart';
import 'package:app_pdf/components/dk_chip.dart';
import 'package:app_pdf/components/dk_pro_badge.dart';
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
    ('pro_badge_chip', const DkProBadgeChipGallery(), 260.0),
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

  group('DkProBadge (DK-0102)', () {
    testWidgets('the word Pro is always shown; 20 or 16 dp tall; pro colours', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [DkProBadge(), DkProBadge(small: true)],
          ),
        ),
      );
      expect(find.text('Pro'), findsNWidgets(2));
      final sizes = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(DkProBadge),
              matching: find.byType(Container),
            ),
          )
          .map((c) => c.constraints!.minHeight);
      expect(sizes, [20, 16]);
      expect(
        tester.widget<Text>(find.text('Pro').first).style!.color,
        DkTokens.light.color.pro,
      );
    });
  });
  group('DkChip (DK-0104)', () {
    testWidgets('filter: off outlined, on filled with a check; 48 to touch; '
        'the selection haptic', (tester) async {
      var on = false;
      await tester.pumpWidget(
        app(
          StatefulBuilder(
            builder: (context, set) => DkChip(
              label: 'Scans',
              selected: on,
              onSelected: (v) => set(() => on = v),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(DkChip)).height, 48);
      BoxDecoration box() =>
          tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byType(DkChip),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      expect(box().color, isNull);
      await tester.tap(find.byType(DkChip));
      await tester.pump();
      expect(on, isTrue);
      expect(played, ['selection']);
      expect(box().color, DkTokens.light.color.primaryContainer);
      expect(find.byType(Icon), findsOneWidget, reason: 'the check');
    });

    testWidgets('choice: on is primary with onPrimary text, visible in Dark', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          DkChip(
            label: 'All',
            selected: true,
            onSelected: (_) {},
            kind: DkChipKind.choice,
          ),
          tokens: DkTokens.dark,
        ),
      );
      await tester.pumpAndSettle();
      final c = DkTokens.dark.color;
      expect(
        tester.widget<Text>(find.text('All')).style!.color,
        c.onPrimary,
        reason: 'selected text stays visible in Dark (#0B1640 on #8AA8FF)',
      );
    });

    testWidgets('semantics: a selected button; disabled ignores taps', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(const DkChip(label: 'Images', selected: true, onSelected: null)),
      );
      expect(
        tester.getSemantics(find.byType(DkChip)),
        isSemantics(
          label: 'Images',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      await tester.tap(find.byType(DkChip));
      expect(played, isEmpty);
      handle.dispose();
    });
  });
}
