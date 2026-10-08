import 'package:app_pdf/components/dk_illustration.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

Widget gallery(DkTokens tokens, List<DkIllustrations> batch) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens),
  home: Scaffold(
    body: Center(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final i in batch) DkIllustration(i, scale: 0.8)],
      ),
    ),
  ),
);

/// The illustrations in batches of five, as they were shipped (DK-0050…).
List<List<DkIllustrations>> get batches => [
  for (var i = 0; i < DkIllustrations.values.length; i += 5)
    DkIllustrations.values.sublist(
      i,
      (i + 5).clamp(0, DkIllustrations.values.length),
    ),
];

/// SVGs decode off the test's fake clock: let them, then draw.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('the light assets are recoloured to the active tokens', () {
    final dark = DkIllustrationColors(DkTokens.dark.color);
    Color map(int argb) => dark.substitute(null, 'path', 'stroke', Color(argb));
    expect(map(0xFF2251E6), DkTokens.dark.color.primary);
    expect(map(0xFF2E3440), DkTokens.dark.color.iconPrimary);
    expect(map(0xFFE6ECFF), DkTokens.dark.color.primaryContainer);
    expect(map(0xFFFFFFFF), DkTokens.dark.color.surface);
    expect(
      map(0xFF8A5A0B),
      const Color(0xFF8A5A0B),
    ); // the paywall's amber stays
    expect(map(0x8CE6ECFF).a, closeTo(0x8C / 255, 0.01)); // opacity kept
    final light = DkIllustrationColors(DkTokens.light.color);
    expect(
      light.substitute(null, 'rect', 'fill', const Color(0xFFFFFFFF)),
      DkTokens.light.color.surface,
    );
  });

  testWidgets('colors: the dark palette on the camera, in a Light app', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: dokuloTheme(DkTokens.light),
        home: const DkIllustration(
          DkIllustrations.cameraDenied,
          colors: DkColors.dark,
        ),
      ),
    );
    final mapper = tester
        .widget<SvgPicture>(find.byType(SvgPicture))
        .bytesLoader;
    expect(mapper, isA<SvgAssetLoader>());
    expect(
      (mapper as SvgAssetLoader).colorMapper,
      const DkIllustrationColors(DkColors.dark),
    );
  });

  testWidgets('decorative unless labelled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: dokuloTheme(DkTokens.light),
        home: const Column(
          children: [
            DkIllustration(DkIllustrations.homeEmpty),
            DkIllustration(
              DkIllustrations.filesEmpty,
              semanticLabel: 'No files yet',
            ),
          ],
        ),
      ),
    );
    await settle(tester);
    expect(find.bySemanticsLabel('No files yet'), findsOneWidget);
    expect(find.bySemanticsLabel('Two pages in a scan frame'), findsNothing);
  });

  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final batch in batches) {
      final first = batch.first.index + 1, last = batch.last.index + 1;
      final range =
          '${first.toString().padLeft(2, '0')}_${last.toString().padLeft(2, '0')}';
      testWidgets('ILL-$range, $name', (tester) async {
        tester.view.physicalSize = const Size(393, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(gallery(tokens, batch));
        await settle(tester);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/illustrations_${range}_$name.png'),
        );
      });
    }
  }

  testWidgets('crisp at 3× density', (tester) async {
    tester.view.physicalSize = const Size(360, 360);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dokuloTheme(DkTokens.light),
        home: const Center(child: DkIllustration(DkIllustrations.homeEmpty)),
      ),
    );
    await settle(tester);
    await expectLater(
      find.byType(DkIllustration),
      matchesGoldenFile('goldens/illustration_home_empty_3x.png'),
    );
  });
}
