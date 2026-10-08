import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_tools/doc_tools.dart' show toolJobIds;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget themed(Widget child, {DkTokens? tokens, TargetPlatform? platform}) {
  final theme = dokuloTheme(tokens ?? DkTokens.light);
  return MaterialApp(
    theme: platform == null ? theme : theme.copyWith(platform: platform),
    home: Scaffold(body: Center(child: child)),
  );
}

Icon iconOf(WidgetTester tester) => tester.widget<Icon>(find.byType(Icon));

/// The icon sheet the goldens show: every size, outlined and filled, and
/// every tool icon.
class _Sheet extends StatelessWidget {
  const _Sheet();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ColoredBox(
      color: t.color.background,
      child: Padding(
        padding: EdgeInsets.all(t.space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (final size in DkIconSize.values) ...[
                  DkIcon(DkIcons.home, size: size),
                  DkIcon(DkIcons.home, size: size, filled: true),
                  SizedBox(width: t.space.s),
                ],
              ],
            ),
            SizedBox(height: t.space.l),
            Wrap(
              spacing: t.space.m,
              runSpacing: t.space.m,
              children: [
                for (final icon in DkIcons.tools.values)
                  DkIcon(icon, size: DkIconSize.xl),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('sizes are the spec\'s five; the font is set as the spec says', (
    tester,
  ) async {
    expect(DkIconSize.values.map((s) => s.dp), [16, 20, 24, 28, 32]);
    await tester.pumpWidget(
      themed(const DkIcon(DkIcons.home, size: DkIconSize.xl)),
    );
    final icon = iconOf(tester);
    expect(icon.size, 28);
    expect(
      (icon.fill, icon.weight, icon.grade, icon.opticalSize),
      (0, 400, 0, 24),
    );
    expect(icon.icon!.fontFamily, 'MaterialSymbolsRounded');
  });

  testWidgets('filled only when asked (selected tab, toggles)', (tester) async {
    await tester.pumpWidget(themed(const DkIcon(DkIcons.home, filled: true)));
    expect(iconOf(tester).fill, 1);
  });

  testWidgets('colour from the tokens, in light and dark', (tester) async {
    await tester.pumpWidget(themed(const DkIcon(DkIcons.search)));
    expect(iconOf(tester).color, DkTokens.light.color.iconPrimary);
    await tester.pumpWidget(
      themed(const DkIcon(DkIcons.search), tokens: DkTokens.dark),
    );
    await tester.pumpAndSettle();
    expect(iconOf(tester).color, DkTokens.dark.color.iconPrimary);
  });

  testWidgets('an icon-only control is labelled for screen readers', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(const DkIcon(DkIcons.close, semanticLabel: 'Close')),
    );
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
  });

  testWidgets('platform icons follow the platform', (tester) async {
    late BuildContext context;
    Widget probe(TargetPlatform platform) => themed(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
      platform: platform,
    );

    await tester.pumpWidget(probe(TargetPlatform.iOS));
    final ios = [
      DkIcons.back(context),
      DkIcons.overflow(context),
      DkIcons.share(context),
      DkIcons.biometrics(context, faceId: true),
    ];
    await tester.pumpWidget(probe(TargetPlatform.android));
    await tester
        .pumpAndSettle(); // the theme animates; its platform flips halfway
    final android = [
      DkIcons.back(context),
      DkIcons.overflow(context),
      DkIcons.share(context),
      DkIcons.biometrics(context, faceId: true),
    ];
    for (var i = 0; i < ios.length; i++) {
      expect(
        ios[i],
        isNot(android[i]),
        reason: 'icon $i should differ by platform',
      );
    }
    expect(
      android.last,
      DkIcons.biometrics(context, faceId: false),
    ); // a fingerprint on Android
  });

  test('every tool has an icon: each ToolJob and every screen tool', () {
    expect(DkIcons.tools, hasLength(31)); // the spec's table (§7)
    for (final id in toolJobIds) {
      expect(DkIcons.tools, contains(id), reason: id);
    }
    expect(() => DkIcons.tool('nope'), throwsArgumentError);
  });

  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('icon sheet, $name', (tester) async {
      tester.view.physicalSize = const Size(393, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(themed(const _Sheet(), tokens: tokens));
      await expectLater(
        find.byType(_Sheet),
        matchesGoldenFile('goldens/dk_icon_$name.png'),
      );
    });
  }
}
