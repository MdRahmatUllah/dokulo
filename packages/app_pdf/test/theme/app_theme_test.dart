import 'package:app_pdf/main.dart';
import 'package:app_pdf/providers/theme_providers.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_overrides.dart';

import '../onboarding_seen.dart';

/// A page thumbnail as DkPageThumb will draw it: a white page, a 1 dp
/// outline, and the theme's thumbnail filter.
class _Thumb extends StatelessWidget {
  const _Thumb();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      body: Center(
        child: Container(
          decoration: BoxDecoration(border: Border.all(color: t.color.outline)),
          child: ColorFiltered(
            colorFilter: t.thumbnailFilter,
            child: Container(
              width: 60,
              height: 85,
              color: t.color.pageWhite,
              padding: const EdgeInsets.all(8),
              alignment: Alignment.topLeft,
              // A line of text: documents stay black on white in both themes.
              child: Container(
                width: 30,
                height: 4,
                color: DkColors.light.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  test('Material\'s ColorScheme comes from the tokens, in both themes', () {
    for (final tokens in [DkTokens.light, DkTokens.dark]) {
      final s = dokuloTheme(tokens).colorScheme, c = tokens.color;
      expect(s.brightness, tokens.brightness);
      expect(
        [s.primary, s.onPrimary, s.primaryContainer, s.onPrimaryContainer],
        [c.primary, c.onPrimary, c.primaryContainer, c.onPrimaryContainer],
      );
      expect(
        [s.surface, s.onSurface, s.onSurfaceVariant],
        [c.surface, c.textPrimary, c.textSecondary],
      );
      expect(
        [s.error, s.onError, s.errorContainer],
        [c.danger, c.onDanger, c.dangerContainer],
      );
      expect([s.outline, s.outlineVariant], [c.outlineStrong, c.outline]);
      expect(
        [s.inverseSurface, s.onInverseSurface, s.inversePrimary],
        [c.inverseSurface, c.onInverseSurface, c.inversePrimary],
        reason: 'toasts use the inverse colours (§29.8)',
      );
      expect(s.surfaceTint, Colors.transparent);
    }
  });

  test('thumbnails are dimmed to 92 % in Dark only', () {
    ColorFilter scale(double b) => ColorFilter.matrix([
      b, 0, 0, 0, 0, //
      0, b, 0, 0, 0, //
      0, 0, b, 0, 0, //
      0, 0, 0, 1, 0, //
    ]);
    expect(DkTokens.light.thumbnailFilter, scale(1));
    expect(DkTokens.dark.thumbnailFilter, scale(0.92));
  });

  testWidgets('a theme change reaches every widget at once', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appThemeModeProvider.overrideWithBuild((ref, _) => ThemeMode.light),
          onboardingSeen,
          ...homeOverrides(),
        ],
        child: const DokuloApp(),
      ),
    );
    await tester.pumpAndSettle();
    DkTokens tokens() => tester.element(find.byType(Scaffold).first).tokens;
    expect(tokens().brightness, Brightness.light);

    ProviderScope.containerOf(tester.element(find.byType(DokuloApp)))
        .read(appThemeModeProvider.notifier)
        .select(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(tokens().color, DkColors.dark);
  });

  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('a page thumbnail stays white, dimmed in Dark: $name', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(120, 120);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dokuloTheme(tokens),
          home: const _Thumb(),
        ),
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/thumbnail_page_$name.png'),
      );
    });
  }
}
