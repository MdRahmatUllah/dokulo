import 'package:app_pdf/catalogue/page_states.dart';
import 'package:app_pdf/components/dk_magnifier.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child, {DkTokens? tokens}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
  home: Scaffold(body: child),
);

void main() {
  // No text in it, so no 200 % variant.
  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('above the finger, and flipped below at the top, $name', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(const MagnifierStates(), tokens: tokens));
      await expectLater(
        find.byType(MagnifierStates),
        matchesGoldenFile('goldens/magnifier_$name.png'),
      );
    });
  }

  testWidgets('96 circle, 4×, centred 80 from the finger; it magnifies the '
      'point under the finger', (tester) async {
    await tester.pumpWidget(
      app(const Stack(children: [DkMagnifier(finger: Offset(200, 300))])),
    );
    final loupe = find.byType(RawMagnifier);
    expect(tester.getSize(loupe), const Size(96, 96));
    expect(tester.getCenter(loupe), const Offset(200, 220));
    final raw = tester.widget<RawMagnifier>(loupe);
    expect(raw.magnificationScale, 4);
    expect(raw.focalPointOffset, const Offset(0, 80));
    final shape = raw.decoration.shape as CircleBorder;
    expect(
      shape.side,
      BorderSide(color: DkTokens.light.color.onCamera, width: 2),
    );
    expect(raw.decoration.shadows, isNotEmpty);

    // Near the top: below the finger, still looking at the finger.
    await tester.pumpWidget(
      app(const Stack(children: [DkMagnifier(finger: Offset(200, 60))])),
    );
    expect(tester.getCenter(loupe), const Offset(200, 140));
    expect(
      tester.widget<RawMagnifier>(loupe).focalPointOffset,
      const Offset(0, -80),
    );
  });

  testWidgets('screen readers skip it', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      app(const Stack(children: [DkMagnifier(finger: Offset(200, 300))])),
    );
    expect(
      find.descendant(
        of: find.byType(DkMagnifier),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
