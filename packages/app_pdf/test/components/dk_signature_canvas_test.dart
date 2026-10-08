import 'dart:ui' as ui;

import 'package:app_pdf/components/dk_signature_canvas.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(DkTokens.light),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 600, height: 200, child: child),
    ),
  ),
);

List<double> widths(DkSignatureController c) => c.lastWidths;

void main() {
  testWidgets('drawing hides the hint; Clear brings it back', (tester) async {
    final c = DkSignatureController();
    addTearDown(c.dispose);
    await tester.pumpWidget(app(DkSignatureCanvas(controller: c)));
    expect(find.text('Sign on the line'), findsOne);
    await tester.dragFrom(const Offset(100, 120), const Offset(200, -40));
    await tester.pump();
    expect(c.isEmpty, isFalse);
    expect(find.text('Sign on the line'), findsNothing);
    c.clear();
    await tester.pump();
    expect(find.text('Sign on the line'), findsOne);
  });

  testWidgets('the baseline sits at 70 % of the height; the hint in DE', (
    tester,
  ) async {
    final c = DkSignatureController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      app(DkSignatureCanvas(controller: c), locale: const Locale('de')),
    );
    final line = find.byWidgetPredicate(
      (w) => w is ColoredBox && w.color == DkTokens.light.color.outlineStrong,
    );
    expect(tester.getRect(line).top, 140);
    expect(tester.getRect(line).height, 1);
    expect(find.text('Auf der Linie unterschreiben'), findsOne);
  });

  test('a fast stroke is thinner than a slow one', () {
    final slow = DkSignatureController()..begin(Offset.zero, 0);
    final fast = DkSignatureController()..begin(Offset.zero, 0);
    for (var i = 1; i <= 20; i++) {
      slow.extend(Offset(i * 2.0, 0), i * 16.0); // 0.125 dp/ms
      fast.extend(Offset(i * 40.0, 0), i * 16.0); // 2.5 dp/ms
    }
    expect(widths(fast).last, lessThan(widths(slow).last));
    for (final w in [...widths(fast), ...widths(slow)]) {
      expect(
        w,
        inInclusiveRange(
          DkSignatureController.minWidth,
          DkSignatureController.maxWidth,
        ),
      );
    }
  });

  test("a stylus's pressure sets the width", () {
    final light = DkSignatureController()..begin(Offset.zero, 0, pressure: 0);
    final hard = DkSignatureController()..begin(Offset.zero, 0, pressure: 1);
    for (var i = 1; i <= 10; i++) {
      light.extend(Offset(i * 10.0, 0), i * 16.0, pressure: 0);
      hard.extend(Offset(i * 10.0, 0), i * 16.0, pressure: 1);
    }
    expect(widths(light).last, closeTo(DkSignatureController.minWidth, 0.01));
    expect(widths(hard).last, closeTo(DkSignatureController.maxWidth, 0.01));
  });

  testWidgets('a stylus on the canvas passes its pressure', (tester) async {
    final c = DkSignatureController();
    addTearDown(c.dispose);
    await tester.pumpWidget(app(DkSignatureCanvas(controller: c)));
    final pen = await tester.createGesture(kind: PointerDeviceKind.stylus);
    await pen.down(const Offset(100, 100));
    for (var i = 1; i <= 10; i++) {
      await pen.moveTo(Offset(100 + i * 10.0, 100));
    }
    await pen.up();
    expect(c.isEmpty, isFalse);
  });

  testWidgets('the PNG: transparent around the ink, trimmed to it', (
    tester,
  ) async {
    final c = DkSignatureController()..begin(const Offset(100, 50), 0);
    for (var i = 1; i <= 10; i++) {
      c.extend(Offset(100 + i * 10.0, 50 + (i.isEven ? 5 : -5)), i * 16.0);
    }
    expect(await DkSignatureController().toPng(), isNull);
    await tester.runAsync(() async {
      final png = (await c.toPng(pixelRatio: 2))!;
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      // 100 wide and 10 tall of ink, plus a pen's width on every side.
      const pad = DkSignatureController.maxWidth;
      expect(image.width, ((100 + 2 * pad) * 2).ceil());
      expect(image.height, ((10 + 2 * pad) * 2).ceil());
      final rgba = (await image.toByteData())!;
      expect(rgba.getUint8(3), 0, reason: 'the corner is transparent');
      var inked = 0;
      for (var i = 3; i < rgba.lengthInBytes; i += 4) {
        if (rgba.getUint8(i) > 0) inked++;
      }
      expect(inked, greaterThan(100));
    });
    c.dispose();
  });
}
