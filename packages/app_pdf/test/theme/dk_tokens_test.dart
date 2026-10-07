import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The token sample page: every colour of this batch as a swatch, every text
/// style, the spacing and radius scale, the elevations.
class _Sample extends StatelessWidget {
  const _Sample();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final swatches = {
      'primary': c.primary,
      'onPrimary': c.onPrimary,
      'primaryPressed': c.primaryPressed,
      'primaryContainer': c.primaryContainer,
      'onPrimaryContainer': c.onPrimaryContainer,
      'background': c.background,
      'surface': c.surface,
      'surfaceRaised': c.surfaceRaised,
      'surfaceSunken': c.surfaceSunken,
      'outline': c.outline,
      'outlineStrong': c.outlineStrong,
      'textPrimary': c.textPrimary,
      'textSecondary': c.textSecondary,
      'textDisabled': c.textDisabled,
      'iconPrimary': c.iconPrimary,
      'iconSecondary': c.iconSecondary,
    };
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(t.space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: t.space.s,
              runSpacing: t.space.s,
              children: [
                for (final e in swatches.entries)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: e.value,
                      borderRadius: BorderRadius.circular(t.radius.s),
                      border: Border.all(color: c.outline),
                    ),
                  ),
              ],
            ),
            SizedBox(height: t.space.l),
            for (final s in [
              t.text.display,
              t.text.titleL,
              t.text.titleM,
              t.text.titleS,
              t.text.bodyL,
              t.text.bodyM,
              t.text.labelL,
              t.text.labelM,
              t.text.caption,
              t.text.mono,
              t.text.numberXL,
            ])
              Text('Aa 1,9 MB', style: s),
            SizedBox(height: t.space.l),
            Row(
              children: [
                for (final shadow in [
                  t.elevation.raised,
                  t.elevation.floating,
                  t.elevation.overlay,
                ])
                  Container(
                    margin: EdgeInsets.only(right: t.space.l),
                    width: 64,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c.surfaceRaised,
                      borderRadius: BorderRadius.circular(t.radius.m),
                      boxShadow: shadow,
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

Widget app(ThemeMode mode) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(DkTokens.light),
  darkTheme: dokuloTheme(DkTokens.dark),
  themeMode: mode,
  home: const _Sample(),
);

void main() {
  testWidgets('token sample page, light', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(ThemeMode.light));
    await expectLater(
      find.byType(_Sample),
      matchesGoldenFile('goldens/tokens_light.png'),
    );
  });

  testWidgets('token sample page, dark', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(ThemeMode.dark));
    await expectLater(
      find.byType(_Sample),
      matchesGoldenFile('goldens/tokens_dark.png'),
    );
  });

  testWidgets('switching the theme animates the tokens, with no glitch', (
    tester,
  ) async {
    await tester.pumpWidget(app(ThemeMode.light));
    Color background() =>
        Theme.of(tester.element(find.byType(_Sample)))
            .extension<DkTokens>()!
            .color
            .background;
    expect(background(), DkTokens.light.color.background);

    await tester.pumpWidget(app(ThemeMode.dark));
    await tester.pump(
      const Duration(milliseconds: 100),
    ); // MaterialApp's theme animation is under way
    final mid = background();
    expect(mid, isNot(DkTokens.light.color.background));
    expect(mid, isNot(DkTokens.dark.color.background));
    await tester.pumpAndSettle();
    expect(background(), DkTokens.dark.color.background);
    expect(tester.takeException(), isNull);
  });

  test('the spec values (UI spec §4.1, §5, §6, §9)', () {
    expect(DkTokens.light.color.primary, const Color(0xFF2251E6));
    expect(DkTokens.dark.color.primary, const Color(0xFF8AA8FF));
    expect(DkTokens.dark.color.surfaceRaised, const Color(0xFF1F232A));
    expect(DkTokens.light.color.iconSecondary, const Color(0xFF6B7380));
    final t = DkTokens.light;
    expect(
      (t.text.bodyL.fontSize, t.text.bodyL.height! * t.text.bodyL.fontSize!),
      (16.0, 24.0),
    );
    expect(t.text.labelL.fontWeight, FontWeight.w600);
    expect((t.space.l, t.radius.m, t.radius.sheet), (16.0, 12.0, 24.0));
    expect(t.motion.standard, const Duration(milliseconds: 220));
    expect(
      DkTokens.dark.elevation.raised,
      isEmpty,
    ); // dark lifts by colour, not shadow
    expect(
      DkTokens.light.lerp(DkTokens.dark, 1).color.primary,
      DkTokens.dark.color.primary,
    );
  });
}
