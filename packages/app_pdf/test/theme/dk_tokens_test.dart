import 'dart:io';

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
      'pro': c.pro,
      'proContainer': c.proContainer,
      'success': c.success,
      'successContainer': c.successContainer,
      'warning': c.warning,
      'warningContainer': c.warningContainer,
      'danger': c.danger,
      'dangerContainer': c.dangerContainer,
      'scrim': c.scrim,
      'cameraChrome': c.cameraChrome,
      'onCamera': c.onCamera,
      'quadFill': c.quadFill,
      'quadStroke': c.quadStroke,
      'pageWhite': c.pageWhite,
      'redactBox': c.redactBox,
      'markup.yellow': t.markup.yellow,
      'markup.green': t.markup.green,
      'markup.blue': t.markup.blue,
      'markup.pink': t.markup.pink,
      'markup.red': t.markup.red,
      'markup.black': t.markup.black,
      'markup.ink': t.markup.ink,
      'compare.added': t.compare.added.background,
      'compare.removed': t.compare.removed.background,
      'compare.changed': t.compare.changed.background,
      'inverseSurface': c.inverseSurface,
      'onInverseSurface': c.onInverseSurface,
      'inversePrimary': c.inversePrimary,
      'state.hover': Color.alphaBlend(t.state.hover, c.surface),
      'state.pressed': Color.alphaBlend(t.state.pressed, c.surface),
      'state.selected': t.state.selected,
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

  group('contrast (WCAG 2.x; UI spec §4.5; the audit, DK-0035)', () {
    for (final tokens in [DkTokens.light, DkTokens.dark]) {
      for (final (pair, fg, bg, minimum) in auditPairs(tokens)) {
        test('${tokens.brightness.name} $pair', () {
          expect(contrast(fg, bg), greaterThanOrEqualTo(minimum));
        });
      }
    }

    test('docs/design/contrast-audit.md is current (DK_UPDATE_AUDIT=1 rewrites it)', () {
      final file = File('../../docs/design/contrast-audit.md');
      final table = auditTable();
      if (Platform.environment['DK_UPDATE_AUDIT'] == '1') {
        file.createSync(recursive: true);
        file.writeAsStringSync(table);
      }
      expect(file.readAsStringSync().replaceAll('\r\n', '\n'), table);
    });
  });

  test(
    'status, camera, document, markup and compare values (UI spec §4.1–§4.3)',
    () {
      final l = DkTokens.light, d = DkTokens.dark;
      expect(
        (l.color.pro, d.color.pro),
        (const Color(0xFF8A5A0B), const Color(0xFFF2C266)),
      );
      expect(
        (l.color.danger, d.color.dangerContainer),
        (const Color(0xFFC8281E), const Color(0xFF3A1614)),
      );
      expect(
        l.color.scrim,
        const Color(0xFF14171C).withValues(alpha: 0x66 / 255),
      ); // 40 %
      expect(
        d.color.scrim,
        const Color(0xFF000000).withValues(alpha: 0x8C / 255),
      ); // 55 %
      expect(
        (l.color.cameraChrome, d.color.cameraChrome),
        (const Color(0x99000000), const Color(0x99000000)),
      );
      expect(
        (l.color.quadFill, d.color.quadStroke),
        (const Color(0x332251E6), const Color(0xFF8AA8FF)),
      );
      for (final t in [l, d]) {
        expect(
          (t.color.pageWhite, t.color.redactBox),
          (const Color(0xFFFFFFFF), const Color(0xFF000000)),
        );
      }
      expect(
        l.markup.ink,
        d.markup.ink,
      ); // stored in the PDF: theme-independent
      expect(
        (l.markup.yellow, l.markup.red, l.markup.ink),
        (
          const Color(0xFFFFE066),
          const Color(0xFFE5484D),
          const Color(0xFF1A2B6D),
        ),
      );
      expect(d.compare.changed, (
        background: const Color(0xFF3A2410),
        text: const Color(0xFFFDB022),
      ));
    },
  );
}

/// WCAG 2.x contrast ratio.
double contrast(Color a, Color b) {
  final (la, lb) = (a.computeLuminance(), b.computeLuminance());
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

/// Every text, icon and input-border pair the app uses, with its minimum:
/// 4.5:1 text, 3:1 icons, input borders and large text (UI spec §4.5).
List<(String, Color, Color, double)> auditPairs(DkTokens tokens) {
  final c = tokens.color, k = tokens.compare;
  const white = Color(0xFFFFFFFF);
  return [
    ('onPrimary on primary', c.onPrimary, c.primary, 4.5),
    (
      'onPrimaryContainer on primaryContainer',
      c.onPrimaryContainer,
      c.primaryContainer,
      4.5,
    ),
    ('primary (links) on surface', c.primary, c.surface, 4.5),
    for (final (bgName, bg) in [
      ('background', c.background),
      ('surface', c.surface),
      ('surfaceRaised', c.surfaceRaised),
      ('surfaceSunken', c.surfaceSunken),
    ]) ...[
      ('textPrimary on $bgName', c.textPrimary, bg, 4.5),
      ('textSecondary on $bgName', c.textSecondary, bg, 4.5),
      ('iconPrimary on $bgName', c.iconPrimary, bg, 3.0),
      ('iconSecondary on $bgName', c.iconSecondary, bg, 3.0),
    ],
    (
      'textPrimary on a pressed row',
      c.textPrimary,
      Color.alphaBlend(tokens.state.pressed, c.surface),
      4.5,
    ),
    (
      'textPrimary on a selected row',
      c.textPrimary,
      tokens.state.selected,
      4.5,
    ),
    (
      'outlineStrong (input border) on surface',
      c.outlineStrong,
      c.surface,
      3.0,
    ),
    (
      'outlineStrong (input border) on surfaceSunken',
      c.outlineStrong,
      c.surfaceSunken,
      3.0,
    ),
    ('pro on proContainer', c.pro, c.proContainer, 4.5),
    ('success on successContainer', c.success, c.successContainer, 4.5),
    ('success (size saved) on surface', c.success, c.surface, 4.5),
    ('warning on warningContainer', c.warning, c.warningContainer, 4.5),
    ('danger on dangerContainer', c.danger, c.dangerContainer, 4.5),
    ('onDanger on danger (Destructive button)', c.onDanger, c.danger, 4.5),
    ('danger (error text) on surface', c.danger, c.surface, 4.5),
    (
      'onCamera on cameraChrome over a white frame',
      c.onCamera,
      Color.alphaBlend(c.cameraChrome, white),
      4.5,
    ),
    (
      'onInverseSurface on inverseSurface (toast)',
      c.onInverseSurface,
      c.inverseSurface,
      4.5,
    ),
    (
      'inversePrimary (toast action) on inverseSurface',
      c.inversePrimary,
      c.inverseSurface,
      4.5,
    ),
    (
      'compare.added text on its background',
      k.added.text,
      k.added.background,
      4.5,
    ),
    (
      'compare.removed text on its background',
      k.removed.text,
      k.removed.background,
      4.5,
    ),
    (
      'compare.changed text on its background',
      k.changed.text,
      k.changed.background,
      4.5,
    ),
  ];
}

/// The audit as Markdown: one row per pair, light and dark side by side.
String auditTable() {
  final light = auditPairs(DkTokens.light), dark = auditPairs(DkTokens.dark);
  String hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  String cell(double r, Color f, Color b, double minimum) =>
      '${r.toStringAsFixed(2)}:1 (${hex(f)} on ${hex(b)})${r >= minimum ? '' : ' **below**'}';
  final rows = [
    for (var i = 0; i < light.length; i++)
      '| ${light[i].$1} | ${light[i].$4.toStringAsFixed(1)}:1 '
          '| ${cell(contrast(light[i].$2, light[i].$3), light[i].$2, light[i].$3, light[i].$4)} '
          '| ${cell(contrast(dark[i].$2, dark[i].$3), dark[i].$2, dark[i].$3, dark[i].$4)} |',
  ];
  return [
    '# Contrast audit (DK-0035)',
    '',
    'Every text, icon and input-border colour pair in `DkTokens`, checked against',
    'WCAG 2.x (UI spec §4.5): 4.5:1 for text, 3:1 for icons, input borders and',
    'large text. Generated by `packages/app_pdf/test/theme/dk_tokens_test.dart`,',
    'which also fails on any pair below its minimum; regenerate with',
    '`DK_UPDATE_AUDIT=1 flutter test test/theme` in `packages/app_pdf`. A new',
    'colour pair gets a row there before it is merged (the PR template asks).',
    'Translucent colours are measured over what they sit on: the camera chrome',
    'over a white frame (the worst case), the pressed overlay over `surface`.',
    'Dividers (`outline`) are decorative and exempt.',
    '',
    '| Pair | Minimum | Light | Dark |',
    '| --- | --- | --- | --- |',
    ...rows,
    '',
  ].join('\n');
}
