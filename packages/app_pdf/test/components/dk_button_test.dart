import 'package:app_pdf/components/dk_button.dart';
import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/screens/catalogue_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

Size sizeOf(WidgetTester tester, String label) => tester.getSize(
  find.ancestor(of: find.text(label), matching: find.byType(Container)).first,
);

void main() {
  // Every variant × state, the sizes and full width: Light/Dark × 100/200 %,
  // English, and German at 200 % (labels wrap to two lines, never cut).
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final (lang, label, scale) in [
      ('en', 'Merge 4 files', 1.0),
      ('en', 'Merge 4 files', 2.0),
      ('de', '4 Dateien zusammenfügen', 2.0),
    ]) {
      final name = '${theme}_${lang}_${(scale * 100).round()}';
      testWidgets('golden: $name', (tester) async {
        tester.view.physicalSize = Size(393, scale > 1 ? 2400 : 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: DkButtonGallery(label: label),
            ),
            tokens: tokens,
            scale: scale,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: 'no overflow');
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/dk_button_$name.png'),
        );
      });
    }
  }

  testWidgets('sizes, padding and minimum widths (UI spec §11.1)', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Column(
          children: [
            for (final s in DkButtonSize.values)
              DkButton(label: s.name[0], onPressed: () {}, size: s),
          ],
        ),
      ),
    );
    expect(sizeOf(tester, 'l'), const Size(120, 52));
    expect(sizeOf(tester, 'r'), const Size(96, 44));
    expect(sizeOf(tester, 'c'), const Size(64, 36));
  });

  testWidgets('every button is at least 48 × 48 to touch', (tester) async {
    await tester.pumpWidget(
      app(
        Center(
          child: DkButton(
            label: 'Go',
            onPressed: () {},
            size: DkButtonSize.compact,
          ),
        ),
      ),
    );
    final target = tester.getSize(find.byType(GestureDetector).first);
    expect(target.height, greaterThanOrEqualTo(48));
    expect(target.width, greaterThanOrEqualTo(48));
    final semantics = tester.getSemantics(find.byType(DkButton));
    expect(semantics.rect.height, greaterThanOrEqualTo(48));
  });

  testWidgets('semantics: a button with its label, enabled or not', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      app(
        Column(
          children: [
            DkButton(
              label: 'Save',
              onPressed: () {},
              icon: DkIcons.tool('merge'),
            ),
            const DkButton(label: 'Delete', onPressed: null),
          ],
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(DkButton).first),
      matchesSemantics(
        label: 'Save',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.byType(DkButton).last),
      matchesSemantics(label: 'Delete', isButton: true, hasEnabledState: true),
    );
    handle.dispose();
  });

  testWidgets('pressed: primary darkens and the button scales to 0.98', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      app(
        Center(
          child: DkButton(label: 'Go', onPressed: () => taps++),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(DkButton)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      0.98,
    );
    final fill =
        (tester
                    .widget<Container>(
                      find
                          .ancestor(
                            of: find.text('Go'),
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration!
                as BoxDecoration)
            .color;
    expect(fill, DkTokens.light.color.primaryPressed);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 200));
    expect(taps, 1);
  });

  testWidgets('disabled and loading buttons ignore taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      app(
        Column(
          children: [
            const DkButton(label: 'Off', onPressed: null),
            DkButton(label: 'Busy', onPressed: () => taps++, loading: true),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Off'));
    await tester.tap(find.text('Busy'));
    expect(taps, 0);
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(of: find.text('Off'), matching: find.byType(Opacity)),
          )
          .opacity,
      0.4,
    );
  });

  testWidgets('loading never changes the width, with or without an icon', (
    tester,
  ) async {
    for (final (icon, buttonSize) in [
      for (final i in [null, DkIcons.tool('merge')])
        for (final s in DkButtonSize.values) (i, s),
    ]) {
      Future<Size> size(bool loading) async {
        await tester.pumpWidget(
          app(
            Center(
              child: DkButton(
                label: 'Compress 3 files',
                onPressed: () {},
                icon: icon,
                size: buttonSize,
                loading: loading,
              ),
            ),
          ),
        );
        return tester.getSize(find.byType(DkButton));
      }

      expect(await size(true), await size(false));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await size(true);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.getSize(find.byType(CircularProgressIndicator)),
        const Size(20, 20),
        reason: '20 dp at every size',
      );
      expect(
        find.text('Compress 3 files'),
        findsOneWidget,
        reason: 'label stays',
      );
    }
  });

  testWidgets('keyboard: focus shows the 2 dp ring and Enter activates', (
    tester,
  ) async {
    var taps = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      app(
        Center(
          child: DkButton(
            label: 'Go',
            onPressed: () => taps++,
            focusNode: focus,
          ),
        ),
      ),
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    focus.requestFocus();
    await tester.pump();
    final ring = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          (w.decoration as BoxDecoration).border ==
              Border.all(color: DkTokens.light.color.focusRing, width: 2),
    );
    expect(ring, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, 1);
  });

  testWidgets('a German label at 200 % wraps to two lines, not cut', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        Padding(
          padding: const EdgeInsets.all(16),
          child: DkButton(
            label: 'Datei zusammenfügen',
            onPressed: () {},
            expand: true,
          ),
        ),
        scale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    // Two lines of labelL at 200 % (2 × 40), the 8 dp padding above and below.
    expect(
      tester.getSize(find.text('Datei zusammenfügen')).height,
      closeTo(80, 0.5),
    );
    expect(tester.getSize(find.byType(DkButton)).height, greaterThan(52));
  });
}
