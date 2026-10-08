import 'package:app_pdf/components/motion/dk_capture_motion.dart';
import 'package:app_pdf/components/motion/dk_reorder_motion.dart';
import 'package:app_pdf/components/motion/dk_success_tick.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [child] in the app theme, with the platform's Reduce Motion [reduce].
Widget host(Widget child, {bool reduce = false, DkTokens? tokens}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dokuloTheme(tokens ?? DkTokens.light),
      // Above the navigator, as the platform's is: overlays see it too.
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
        child: app!,
      ),
      home: Scaffold(body: child),
    );

const ms = Duration(milliseconds: 1);

/// The flash overlay's opacity, or 0 when it is gone.
double flash(WidgetTester tester) {
  final box = find.descendant(
    of: find.byType(DkCaptureFlash),
    matching: find.byType(ColoredBox),
  );
  if (box.evaluate().isEmpty) return 0;
  return tester.widget<ColoredBox>(box.last).color.a;
}

double scaleOf(WidgetTester tester, Finder f) => tester
    .widget<Transform>(
      find.descendant(of: f, matching: find.byType(Transform)).first,
    )
    .transform
    .getMaxScaleOnAxis();

void main() {
  group('Scan capture (DK-0040)', () {
    Widget viewfinder(int captures, {bool reduce = false}) => host(
      DkCaptureFlash(
        captures: captures,
        child: const SizedBox(width: 200, height: 300),
      ),
      reduce: reduce,
    );

    testWidgets('the flash: 95 % white, gone at 80 ms', (tester) async {
      await tester.pumpWidget(viewfinder(0));
      expect(flash(tester), 0, reason: 'no flash before a capture');
      await tester.pumpWidget(viewfinder(1));
      expect(flash(tester), closeTo(0.95, 0.01));
      await tester.pump(ms * 40);
      expect(flash(tester), closeTo(0.475, 0.05));
      await tester.pump(ms * 60); // 100 ms: within 20 ms of the end
      expect(flash(tester), 0);
    });

    testWidgets('no flash with Reduce Motion', (tester) async {
      await tester.pumpWidget(viewfinder(0, reduce: true));
      await tester.pumpWidget(viewfinder(1, reduce: true));
      expect(flash(tester), 0);
    });

    Future<(Rect Function(), Future<void>)> fly(
      WidgetTester tester, {
      bool reduce = false,
    }) async {
      await tester.pumpWidget(host(const SizedBox.expand(), reduce: reduce));
      final landed = flyCapturedPage(
        tester.element(find.byType(Scaffold)),
        page: const ColoredBox(key: ValueKey('page'), color: Color(0xFFFFFFFF)),
        from: const Rect.fromLTWH(40, 80, 300, 400),
        to: const Rect.fromLTWH(16, 700, 42, 56),
      );
      await tester.pump();
      return (() => tester.getRect(find.byKey(const ValueKey('page'))), landed);
    }

    testWidgets('the page waits for the flash, then flies 320 ms into the '
        'tray', (tester) async {
      final (rect, landed) = await fly(tester);
      var done = false;
      landed.then((_) => done = true);
      await tester.pump(ms * 70);
      expect(rect(), const Rect.fromLTWH(40, 80, 300, 400));
      await tester.pump(ms * 170); // halfway through the flight
      expect(rect().top, inExclusiveRange(80, 700));
      expect(rect().width, inExclusiveRange(42, 300));
      await tester.pump(ms * 180); // 420 ms: within 20 ms of 400
      expect(done, isTrue);
      expect(find.byKey(const ValueKey('page')), findsNothing);
    });

    testWidgets('the scanner closes mid-flight: the future still completes', (
      tester,
    ) async {
      final (_, landed) = await fly(tester);
      var done = false;
      landed.then((_) => done = true);
      await tester.pump(ms * 150);
      await tester.pumpWidget(const SizedBox()); // the overlay is gone
      await tester.pump();
      expect(done, isTrue);
    });

    testWidgets('Reduce Motion: it fades where it is, in 120 ms', (
      tester,
    ) async {
      final (rect, landed) = await fly(tester, reduce: true);
      var done = false;
      landed.then((_) => done = true);
      await tester.pump(ms * 60);
      expect(rect(), const Rect.fromLTWH(40, 80, 300, 400));
      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.byKey(const ValueKey('page')),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, closeTo(0.5, 0.1));
      await tester.pump(ms * 80);
      expect(done, isTrue);
    });

    testWidgets('the badge pops ×1.35 and back in 320 ms when the count '
        'changes', (tester) async {
      Widget badge(int n, {bool reduce = false}) => host(
        Center(
          child: DkPop(value: n, child: Text('$n')),
        ),
        reduce: reduce,
      );
      await tester.pumpWidget(badge(1));
      final pop = find.byType(DkPop);
      expect(scaleOf(tester, pop), 1);
      await tester.pumpWidget(badge(2));
      var peak = 1.0;
      for (var t = 0; t < 320; t += 20) {
        await tester.pump(ms * 20);
        peak = scaleOf(tester, pop) > peak ? scaleOf(tester, pop) : peak;
      }
      expect(peak, greaterThan(1.3));
      await tester.pump(ms * 20);
      expect(scaleOf(tester, pop), closeTo(1, 0.01));

      await tester.pumpWidget(badge(3, reduce: true));
      await tester.pump(ms * 60);
      expect(scaleOf(tester, pop), 1, reason: 'no movement');
      expect(
        tester
            .widget<Opacity>(
              find.descendant(of: pop, matching: find.byType(Opacity)),
            )
            .opacity,
        closeTo(0.5, 0.1),
      );
    });
  });

  group('Success tick (DK-0041)', () {
    testWidgets('the circle draws in 200 ms, then the check in 120 ms', (
      tester,
    ) async {
      await tester.pumpWidget(host(const Center(child: DkSuccessTick())));
      // The painter's progress: (circle, check), each 0–1.
      (double, double) drawn() {
        final dynamic p = tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(DkSuccessTick),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter;
        return (p.circle as double, p.check as double);
      }

      expect(drawn(), (0.0, 0.0));
      await tester.pump(ms * 100);
      expect(drawn().$1, inExclusiveRange(0, 1));
      await tester.pump(ms * 100); // 200 ms
      expect(drawn(), (1.0, 0.0));
      await tester.pump(ms * 60);
      expect(drawn().$2, inExclusiveRange(0, 1));
      await tester.pump(ms * 60); // 320 ms
      expect(drawn(), (1.0, 1.0));
      expect(find.bySemanticsLabel(RegExp('.')), findsNothing);
    });

    testWidgets('the number counts from the old to the new value in 400 ms, '
        'after the tick', (tester) async {
      String mb(double v) => '${v.toStringAsFixed(1)} MB';
      await tester.pumpWidget(
        host(Center(child: DkCountUp(from: 8.4, to: 1.9, format: mb))),
      );
      expect(find.text('8.4 MB'), findsOneWidget);
      expect(find.bySemanticsLabel('1.9 MB'), findsOneWidget);
      await tester.pump(ms * 320);
      expect(find.text('8.4 MB'), findsOneWidget);
      await tester.pump(ms * 200);
      expect(find.text('8.4 MB'), findsNothing);
      expect(find.text('1.9 MB'), findsNothing, reason: 'still counting');
      await tester.pump(ms * 200);
      expect(find.text('1.9 MB'), findsOneWidget);
    });

    testWidgets('Reduce Motion: tick and number fade in, 120 ms', (
      tester,
    ) async {
      String mb(double v) => '${v.toStringAsFixed(1)} MB';
      await tester.pumpWidget(
        host(
          Column(
            children: [
              const DkSuccessTick(),
              DkCountUp(from: 8.4, to: 1.9, format: mb),
            ],
          ),
          reduce: true,
        ),
      );
      expect(find.text('1.9 MB'), findsOneWidget);
      expect(find.text('8.4 MB'), findsNothing);
      await tester.pump(ms * 60);
      for (final o in tester.widgetList<Opacity>(find.byType(Opacity))) {
        expect(o.opacity, closeTo(0.5, 0.1));
      }
      await tester.pump(ms * 60);
      await tester.pumpAndSettle();
    });
  });

  group('Tile reorder and page drop (DK-0042, DK-0043)', () {
    testWidgets('a picked tile lifts ×1.04 with the floating shadow in '
        '220 ms', (tester) async {
      Widget tile(bool lifted, {bool reduce = false}) => host(
        Center(
          child: DkLift(
            lifted: lifted,
            child: const SizedBox(width: 60, height: 60),
          ),
        ),
        reduce: reduce,
      );
      double scale() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
      List<BoxShadow>? shadow() =>
          ((tester
                      .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                      .decoration)!
                  as BoxDecoration)
              .boxShadow;
      await tester.pumpWidget(tile(false));
      await tester.pumpWidget(tile(true));
      expect(scale(), 1.04);
      expect(shadow(), DkTokens.light.elevation.floating);
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
        const Duration(milliseconds: 220),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(tile(true, reduce: true));
      expect(scale(), 1, reason: 'Reduce Motion: no scale');
      expect(shadow(), DkTokens.light.elevation.floating);
      expect(
        tester
            .widget<AnimatedContainer>(find.byType(AnimatedContainer))
            .duration,
        const Duration(milliseconds: 120),
      );
    });

    Widget grid(Rect slot, {bool reduce = false}) => host(
      Stack(
        children: [
          DkSlot(
            rect: slot,
            child: const ColoredBox(
              key: ValueKey('tile'),
              color: Color(0xFFFFFFFF),
            ),
          ),
        ],
      ),
      reduce: reduce,
    );
    const a = Rect.fromLTWH(0, 0, 60, 80), b = Rect.fromLTWH(80, 0, 60, 80);

    testWidgets('the others slide to their new place in 220 ms', (
      tester,
    ) async {
      Rect tile() => tester.getRect(find.byKey(const ValueKey('tile')));
      await tester.pumpWidget(grid(a));
      await tester.pumpWidget(grid(b));
      await tester.pump(ms * 110);
      expect(tile().left, inExclusiveRange(0, 80));
      await tester.pump(ms * 110);
      expect(tile(), b);
    });

    testWidgets('Reduce Motion: it appears at the new place, fading 120 ms', (
      tester,
    ) async {
      await tester.pumpWidget(grid(a, reduce: true));
      await tester.pumpWidget(grid(b, reduce: true));
      await tester.pump();
      expect(tester.getRect(find.byKey(const ValueKey('tile'))), b);
      await tester.pump(ms * 60);
      expect(
        tester
            .widget<FadeTransition>(find.byType(FadeTransition).last)
            .opacity
            .value,
        closeTo(0.5, 0.1),
      );
      await tester.pump(ms * 60);
    });

    testWidgets('the insertion line: an 8 dp wide I-beam, steady', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const Center(child: DkInsertionLine(length: 80))),
      );
      expect(tester.getSize(find.byType(DkInsertionLine)), const Size(8, 80));
      expect(tester.hasRunningAnimations, isFalse, reason: 'no pulse');
      await tester.pumpWidget(
        host(
          const Center(
            child: DkInsertionLine(length: 60, axis: Axis.horizontal),
          ),
        ),
      );
      expect(tester.getSize(find.byType(DkInsertionLine)), const Size(60, 8));
    });
  });

  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('at rest: tick, lifted tile, insertion line ($name)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(240, 140);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                spacing: 24,
                children: [
                  const DkSuccessTick(),
                  DkLift(
                    lifted: true,
                    borderRadius: BorderRadius.circular(
                      context.tokens.radius.m,
                    ),
                    child: Container(
                      width: 60,
                      height: 80,
                      decoration: BoxDecoration(
                        color: context.tokens.color.surfaceRaised,
                        borderRadius: BorderRadius.circular(
                          context.tokens.radius.m,
                        ),
                      ),
                    ),
                  ),
                  const DkInsertionLine(length: 80),
                ],
              ),
            ),
          ),
          tokens: tokens,
        ),
      );
      await tester.pump(const Duration(seconds: 1)); // the line at full
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/motion_at_rest_$name.png'),
      );
    });
  }
}
