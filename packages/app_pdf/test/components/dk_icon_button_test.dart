import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/components/dk_icon_button.dart';
import 'package:app_pdf/catalogue/icon_button_states.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child, {DkTokens? tokens, double scale = 1}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: app!,
  ),
  home: Scaffold(body: child),
);

BoxDecoration circleOf(WidgetTester tester, Finder button) =>
    tester
            .widget<AnimatedContainer>(
              find.descendant(
                of: button,
                matching: find.byType(AnimatedContainer),
              ),
            )
            .decoration!
        as BoxDecoration;

void main() {
  // Icons don't scale with text, so 200 % must look the same as 100 %.
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final scale in [1.0, 2.0]) {
      final name = '${theme}_${(scale * 100).round()}';
      testWidgets('golden: $name', (tester) async {
        tester.view.physicalSize = const Size(240, 200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            const Padding(
              padding: EdgeInsets.all(16),
              child: DkIconButtonGallery(),
            ),
            tokens: tokens,
            scale: scale,
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/dk_icon_button_$name.png'),
        );
      });
    }
  }

  testWidgets('a 44 dp button with a 48 dp touch area and a 24 dp icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Center(
          child: DkIconButton(
            icon: DkIcons.pin,
            tooltip: 'Pin',
            onPressed: () {},
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(DkIconButton)), const Size(48, 48));
    expect(
      tester.getSize(
        find.byWidgetPredicate((w) => w is SizedBox && w.width == 44),
      ),
      const Size(44, 44),
    );
    expect(tester.widget<Icon>(find.byType(Icon)).size, 24);
  });

  testWidgets('variants: tonal 36 circle, on camera 40 at 35 % black', (
    tester,
  ) async {
    final c = DkTokens.light.color;
    await tester.pumpWidget(
      app(
        Row(
          children: [
            for (final v in DkIconButtonVariant.values)
              DkIconButton(
                key: ValueKey(v),
                icon: DkIcons.pin,
                tooltip: v.name,
                onPressed: () {},
                variant: v,
              ),
          ],
        ),
      ),
    );
    Finder of(DkIconButtonVariant v) => find.byKey(ValueKey(v));
    expect(circleOf(tester, of(DkIconButtonVariant.plain)).color, isNull);
    expect(
      circleOf(tester, of(DkIconButtonVariant.tonal)).color,
      c.primaryContainer,
    );
    expect(
      tester
          .getSize(
            find.descendant(
              of: of(DkIconButtonVariant.tonal),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .width,
      36,
    );
    final camera = circleOf(tester, of(DkIconButtonVariant.onCamera)).color!;
    expect(camera.a, closeTo(0.35, 0.01));
    expect(camera.r, 0);
  });

  testWidgets('selected: filled icon on the tonal circle, and announced', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      app(
        Center(
          child: DkIconButton(
            icon: DkIcons.pin,
            tooltip: 'Pin',
            onPressed: () {},
            selected: true,
          ),
        ),
      ),
    );
    expect(tester.widget<Icon>(find.byType(Icon)).fill, 1);
    expect(
      circleOf(tester, find.byType(DkIconButton)).color,
      DkTokens.light.color.primaryContainer,
    );
    expect(
      tester.getSemantics(find.byType(DkIconButton)),
      matchesSemantics(
        label: 'Pin',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('pressed overlay; disabled at 40 % ignores taps; tooltip', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      app(
        Row(
          children: [
            DkIconButton(
              key: const ValueKey('on'),
              icon: DkIcons.pin,
              tooltip: 'Pin',
              onPressed: () => taps++,
            ),
            DkIconButton(
              key: const ValueKey('off'),
              icon: DkIcons.delete,
              tooltip: 'Delete',
              onPressed: null,
            ),
          ],
        ),
      ),
    );
    final on = find.byKey(const ValueKey('on'));
    final gesture = await tester.startGesture(tester.getCenter(on));
    await tester.pump(const Duration(milliseconds: 150));
    expect(circleOf(tester, on).color, DkTokens.light.state.pressed);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 150));
    expect(taps, 1);

    final off = find.byKey(const ValueKey('off'));
    await tester.tap(off);
    expect(taps, 1);
    expect(
      tester
          .widget<Opacity>(
            find.descendant(of: off, matching: find.byType(Opacity)),
          )
          .opacity,
      0.4,
    );

    await tester.longPress(on);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Pin'), findsOneWidget, reason: 'the tooltip');
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });
}
