import 'package:app_pdf/catalogue/crop_states.dart';
import 'package:app_pdf/components/dk_crop_overlay.dart';
import 'package:app_pdf/components/dk_magnifier.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'a11y.dart';

Widget app(
  Widget home, {
  DkTokens? tokens,
  double scale = 1,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: home),
);

void phone(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A 300 × 400 overlay at the top left, recording every change.
class Harness extends StatefulWidget {
  const Harness({
    super.key,
    required this.changes,
    this.rectangle = false,
    this.snapTo,
    this.taps,
  });

  final List<List<Offset>> changes;
  final bool rectangle;
  final List<Offset>? snapTo;
  final List<String>? taps;

  static const start = [
    Offset(0.2, 0.2),
    Offset(0.8, 0.2),
    Offset(0.8, 0.8),
    Offset(0.2, 0.8),
  ];

  @override
  State<Harness> createState() => _HarnessState();
}

class _HarnessState extends State<Harness> {
  var quad = Harness.start;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 344,
      child: DkCropOverlay(
        image: const ColoredBox(color: Color(0xFFFFFFFF)),
        aspectRatio: 3 / 4,
        quad: quad,
        rectangle: widget.rectangle,
        snapTo: widget.snapTo,
        onChanged: (q) {
          widget.changes.add(q);
          setState(() => quad = q);
        },
        onAuto: () => widget.taps?.add('auto'),
        onFullPage: () => widget.taps?.add('full'),
        onReset: () => widget.taps?.add('reset'),
      ),
    ),
  );
}

/// Fractions of the 300 × 400 image, in pixels.
/// The overlay keeps its image 22 dp in on every side (half a handle's 44
/// target): a fraction's point on the image, and on the screen.
const inset = 22.0;
Offset local(Offset f) => Offset(f.dx * 300, f.dy * 400);
Offset px(Offset f) => local(f) + const Offset(inset, inset);

void main() {
  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final (lang, scale) in [('en', 1.0), ('en', 2.0), ('de', 2.0)]) {
      final file = 'crop_${name}_${lang}_${(scale * 100).round()}';
      testWidgets('golden: $file', (tester) async {
        phone(tester, const Size(393, 900));
        await tester.pumpWidget(
          app(
            const SingleChildScrollView(child: CropStates()),
            tokens: tokens,
            scale: scale,
            locale: Locale(lang),
          ),
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(CropStates),
          matchesGoldenFile('goldens/$file.png'),
        );
      });
    }
  }

  testWidgets('a corner follows the finger and stays where it was let go; '
      'the magnifier shows while dragging', (tester) async {
    phone(tester, const Size(393, 600));
    final changes = <List<Offset>>[];
    await tester.pumpWidget(app(Harness(changes: changes)));
    final gesture = await tester.startGesture(px(Harness.start[0]));
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    expect(find.byType(DkMagnifier), findsOne);
    final last = changes.last;
    // The drag-start slop is part of the movement: the corner is under the
    // finger, not behind it.
    expect(local(last[0]).dx, closeTo(60 + 30, 0.5));
    expect(local(last[0]).dy, closeTo(80 + 20, 0.5));
    await gesture.up();
    await tester.pump();
    expect(find.byType(DkMagnifier), findsNothing);
    // Letting go changes nothing: no jump.
    expect(changes.last, last);
    expect(changes.last[1], Harness.start[1]);
  });

  testWidgets('a corner snaps to a detected corner within 16', (tester) async {
    phone(tester, const Size(393, 600));
    final changes = <List<Offset>>[];
    const detected = Offset(0.1, 0.1); // (30, 40)
    await tester.pumpWidget(
      app(
        Harness(
          changes: changes,
          snapTo: const [detected, Offset(0.9, 0.1), Offset(0.9, 0.9)],
        ),
      ),
    );
    final gesture = await tester.startGesture(px(Harness.start[0]));
    // From (60, 80) to (40, 50): 14 from the detected corner.
    await gesture.moveBy(const Offset(-20, -30));
    await tester.pump();
    expect(changes.last[0], detected);
    await gesture.up();
  });

  testWidgets('rectangle: a corner moves its two sides; the quad stays '
      'convex', (tester) async {
    phone(tester, const Size(393, 600));
    final changes = <List<Offset>>[];
    await tester.pumpWidget(app(Harness(changes: changes, rectangle: true)));
    final gesture = await tester.startGesture(px(Harness.start[0]));
    await gesture.moveBy(const Offset(-30, -40));
    await tester.pump();
    final q = changes.last.map(local).toList();
    expect(q[0], const Offset(30, 40));
    expect(q[1].dy, 40); // the top side moved
    expect(q[3].dx, 30); // the left side moved
    expect(q[2], local(Harness.start[2]));
    await gesture.up();

    // Dragging a corner across the opposite one is refused.
    changes.clear();
    final cross = await tester.startGesture(px(Harness.start[2]));
    await cross.moveBy(const Offset(-260, -340));
    await tester.pump();
    for (final q in changes) {
      expect(q[2].dx, greaterThan(q[0].dx));
      expect(q[2].dy, greaterThan(q[0].dy));
    }
    await cross.up();
  });

  testWidgets('Auto, Full page and Reset: the way without dragging; '
      'pressable, labelled, big enough', (tester) async {
    phone(tester, const Size(393, 600));
    final handle = tester.ensureSemantics();
    final taps = <String>[];
    await tester.pumpWidget(app(Harness(changes: [], taps: taps)));
    await tester.tap(find.text('Auto'));
    await tester.tap(find.text('Full page'));
    await tester.tap(find.text('Reset'));
    expect(taps, ['auto', 'full', 'reset']);
    expectPressableButtons(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('no callback, no button', (tester) async {
    phone(tester, const Size(393, 600));
    await tester.pumpWidget(
      app(
        SizedBox(
          width: 300,
          child: DkCropOverlay(
            image: const SizedBox(),
            aspectRatio: 3 / 4,
            quad: Harness.start,
            rectangle: true,
            onChanged: (_) {},
            onReset: () {},
          ),
        ),
      ),
    );
    expect(find.text('Reset'), findsOne);
    expect(find.text('Full page'), findsNothing);
    expect(find.text('Auto'), findsNothing);
  });

  testWidgets('a corner on the image corner (Full page) is grabbable from '
      'outside the image: the overlay covers every handle', (tester) async {
    phone(tester, const Size(393, 600));
    final changes = <List<Offset>>[];
    await tester.pumpWidget(
      app(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 344,
            child: DkCropOverlay(
              image: const ColoredBox(color: Color(0xFFFFFFFF)),
              aspectRatio: 3 / 4,
              quad: const [
                Offset(0, 0),
                Offset(1, 0),
                Offset(1, 1),
                Offset(0, 1),
              ],
              onChanged: changes.add,
            ),
          ),
        ),
      ),
    );
    // 15 dp up and left of the image's top-left corner, inside the handle.
    final gesture = await tester.startGesture(
      px(Offset.zero) - const Offset(15, 15),
    );
    await gesture.moveBy(const Offset(40, 50));
    await tester.pump();
    await gesture.up();
    expect(changes, isNotEmpty);
    expect(local(changes.last[0]).dx, greaterThan(0));
    // Every handle's 44 target lies inside the overlay.
    final overlay = tester.getRect(find.byType(DkCropOverlay));
    for (final f in const [
      Offset(0, 0),
      Offset(1, 0),
      Offset(1, 1),
      Offset(0, 1),
    ]) {
      final hit = Rect.fromCenter(center: px(f), width: 44, height: 44);
      expect(
        overlay.contains(hit.topLeft) &&
            overlay.contains(hit.bottomRight - const Offset(0.1, 0.1)),
        isTrue,
        reason: '$f',
      );
    }
  });
}
