import 'package:app_pdf/components/dk_number_text.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_layout.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget themed(Widget child, DkTokens tokens) => MaterialApp(
  theme: dokuloTheme(tokens),
  home: Scaffold(body: child),
);

/// The type scale, every style named, plus tabular numbers.
class _TypeScale extends StatelessWidget {
  const _TypeScale();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final styles = {
      'display': t.text.display,
      'titleL': t.text.titleL,
      'titleM': t.text.titleM,
      'titleS': t.text.titleS,
      'bodyL': t.text.bodyL,
      'bodyM': t.text.bodyM,
      'labelL': t.text.labelL,
      'labelM': t.text.labelM,
      'caption': t.text.caption,
      'mono': t.text.mono,
      'numberXL': t.text.numberXL,
    };
    return ColoredBox(
      color: t.color.background,
      child: Padding(
        padding: EdgeInsets.all(t.space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final MapEntry(key: name, value: style) in styles.entries)
              Text('$name Aa 1.9', style: style),
            DkNumberText('42 of 120', style: t.text.bodyM),
          ],
        ),
      ),
    );
  }
}

/// The four elevation levels on the background.
class _Levels extends StatelessWidget {
  const _Levels();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ColoredBox(
      color: t.color.background,
      child: Padding(
        padding: EdgeInsets.all(t.space.xl),
        child: Wrap(
          spacing: t.space.xl,
          runSpacing: t.space.xl,
          children: [
            for (final level in DkLevel.values)
              Container(
                width: 150,
                height: 90,
                decoration: t.surfaceAt(
                  level,
                  radius: BorderRadius.circular(t.radius.m),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('type (DK-0036)', () {
    test('result numbers use tabular figures; mono has an iOS fallback', () {
      final text = DkTokens.light.text;
      expect(
        text.numberXL.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(text.mono.fontFamily, 'monospace');
      expect(text.mono.fontFamilyFallback, contains('Menlo'));
      // Still the spec's numbers (agent-1's test covers every style).
      expect((text.numberXL.fontSize, text.numberXL.height! * 32), (32, 38));
    });

    testWidgets('DkNumberText keeps its style and adds tabular figures', (
      tester,
    ) async {
      await tester.pumpWidget(
        themed(
          DkNumberText('1.9 MB', style: DkTokens.light.text.titleM),
          DkTokens.light,
        ),
      );
      final style = tester.widget<Text>(find.text('1.9 MB')).style!;
      expect(style.fontFeatures, [const FontFeature.tabularFigures()]);
      expect(style.fontSize, 18);
    });
  });

  group('borders, surfaces and grid (DK-0038)', () {
    test('borders: 1 dp at rest, 2 dp focused, error and selection', () {
      final t = DkTokens.light;
      expect(
        (t.divider.width, t.divider.color, t.dividerInset),
        (1, t.color.outline, 16),
      );
      expect(
        (t.inputRest.width, t.inputRest.color),
        (1, t.color.outlineStrong),
      );
      expect(
        (t.inputFocused.width, t.inputFocused.color),
        (2, t.color.primary),
      );
      expect((t.inputError.width, t.inputError.color), (2, t.color.danger));
      expect(
        (t.selectionRing.width, t.selectionRing.color),
        (2, t.color.primary),
      );
    });

    test(
      'light lifts with shadows; dark with lighter surfaces and outlines',
      () {
        final light = DkTokens.light, dark = DkTokens.dark;
        final lightRaised = light.surfaceAt(DkLevel.raised);
        expect(
          (
            lightRaised.color,
            lightRaised.border,
            lightRaised.boxShadow!.isNotEmpty,
          ),
          (light.color.surface, null, true),
        );
        final darkRaised = dark.surfaceAt(DkLevel.raised);
        expect(darkRaised.color, dark.color.surfaceRaised);
        expect(darkRaised.border, isNotNull);
        expect(darkRaised.boxShadow, isEmpty);
        expect(dark.surfaceAt(DkLevel.overlay).boxShadow, isEmpty);
        expect(dark.surfaceAt(DkLevel.floating).boxShadow, isNotEmpty);
        for (final t in [light, dark]) {
          final flat = t.surfaceAt(DkLevel.flat);
          expect(flat.boxShadow, isNull);
          expect(flat.border, isNotNull);
        }
      },
    );

    test('the grid per device class', () {
      expect(DkGrid.forWidth(393), DkGrid.phone);
      expect(DkGrid.forWidth(599), DkGrid.phone);
      expect(DkGrid.forWidth(600), DkGrid.smallTablet);
      expect(DkGrid.forWidth(840), DkGrid.largeTablet);
      expect(
        (DkGrid.phone.margin, DkGrid.phone.columns, DkGrid.phone.gutter),
        (16, 4, 12),
      );
      expect(
        (
          DkGrid.smallTablet.margin,
          DkGrid.smallTablet.columns,
          DkGrid.smallTablet.gutter,
        ),
        (24, 8, 16),
      );
      expect(
        (
          DkGrid.largeTablet.columns,
          DkGrid.largeTablet.gutter,
          DkGrid.largeTablet.rail,
        ),
        (12, 16, 80),
      );
    });
  });

  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('type scale, $name', (tester) async {
      tester.view.physicalSize = const Size(393, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(themed(const _TypeScale(), tokens));
      await expectLater(
        find.byType(_TypeScale),
        matchesGoldenFile('goldens/type_scale_$name.png'),
      );
    });

    testWidgets('elevation levels, $name', (tester) async {
      tester.view.physicalSize = const Size(393, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(themed(const _Levels(), tokens));
      await expectLater(
        find.byType(_Levels),
        matchesGoldenFile('goldens/elevation_$name.png'),
      );
    });
  }
}
