import 'package:app_pdf/catalogue/logo_states.dart';
import 'package:app_pdf/components/dk_logo.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child, {DkTokens? tokens, double scale = 1}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: app!,
  ),
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

Future<void> settle(WidgetTester tester) async {
  // SVGs decode off the fake clock.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump();
}

void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('golden: $theme', (tester) async {
      tester.view.physicalSize = const Size(393, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(const LogoStates(), tokens: tokens));
      await settle(tester);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/dk_logo_$theme.png'),
      );
    });
  }

  testWidgets('the symbol keeps the fold height clear around it', (
    tester,
  ) async {
    await tester.pumpWidget(app(const Center(child: DkLogo.symbol())));
    // 72 + 2 × 13.5
    expect(tester.getSize(find.byType(DkLogo)), const Size(99, 99));
    expect(DkLogo.clearSpace(64), 12);
  });

  testWidgets('24 dp and below use the small cut', (tester) async {
    String asset(WidgetTester tester) =>
        (tester.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader
                as SvgAssetLoader)
            .assetName;
    await tester.pumpWidget(app(const DkLogo.symbol(size: 24)));
    expect(asset(tester), 'assets/brand/dokulo_symbol_small.svg');
    await tester.pumpWidget(app(const DkLogo.symbol(size: 56)));
    expect(asset(tester), 'assets/brand/dokulo_symbol.svg');
  });

  testWidgets('one image node "Dokulo"; the wordmark ignores text size', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(app(const DkLogo.lockup(), scale: 2));
    expect(find.bySemanticsLabel('Dokulo'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(DkLogo)),
      isSemantics(label: 'Dokulo', isImage: true),
    );
    final text = tester.widget<Text>(find.text('Dokulo'));
    expect(text.textScaler, TextScaler.noScaling);
    handle.dispose();
  });

  testWidgets('a colour makes it monochrome', (tester) async {
    await tester.pumpWidget(app(const DkLogo.symbol(color: Color(0xFFFFFFFF))));
    expect(
      tester.widget<SvgPicture>(find.byType(SvgPicture)).colorFilter,
      const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn),
    );
  });
}
