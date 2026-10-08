import 'package:app_pdf/catalogue/bar_states.dart';
import 'package:app_pdf/components/dk_bottom_bars.dart';
import 'package:app_pdf/components/dk_camera_top_bar.dart';
import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(
  Widget home, {
  DkTokens? tokens,
  Locale locale = const Locale('en'),
  double textScale = 1,
  bool reduceMotion = false,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: reduceMotion,
      textScaler: TextScaler.linear(textScale),
    ),
    child: child!,
  ),
  home: Scaffold(body: home),
);

const actions = [
  DkBarAction(icon: DkIcons.move, label: 'Move', onPressed: _none),
  DkBarAction(icon: DkIcons.duplicate, label: 'Copy', onPressed: _none),
  DkBarAction(icon: DkIcons.info, label: 'Info', onPressed: null),
  DkBarAction(icon: DkIcons.delete, label: 'Delete', onPressed: _none),
  DkBarAction(icon: DkIcons.rename, label: 'Rename', onPressed: _none),
];

void _none() {}

void main() {
  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('bottom bars and the camera bar, $name, '
          '${(scale * 100).round()} %', (tester) async {
        tester.view.physicalSize = Size(393, scale == 1 ? 420 : 520);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(const BottomBarStates(), tokens: tokens, textScale: scale),
        );
        await expectLater(
          find.byType(BottomBarStates),
          matchesGoldenFile(
            'goldens/bottom_bars_${name}_${(scale * 100).round()}.png',
          ),
        );
      });
    }
  }

  testWidgets('selection bar: 64 tall, actions fire, disabled ones do not', (
    tester,
  ) async {
    final done = <String>[];
    await tester.pumpWidget(
      app(
        Align(
          alignment: Alignment.bottomCenter,
          child: DkSelectionBar(
            actions: [
              DkBarAction(
                icon: DkIcons.move,
                label: 'Move',
                onPressed: () => done.add('move'),
              ),
              const DkBarAction(
                icon: DkIcons.info,
                label: 'Info',
                onPressed: null,
              ),
              DkBarAction(
                icon: DkIcons.delete,
                label: 'Delete',
                onPressed: () => done.add('delete'),
              ),
              const DkBarAction(
                icon: DkIcons.rename,
                label: 'Rename',
                onPressed: _none,
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(DkSelectionBar)).height, 64);
    await tester.tap(find.text('Move'));
    await tester.tap(find.text('Info'));
    await tester.tap(find.text('Delete'));
    expect(done, ['move', 'delete']);
  });

  testWidgets('viewer bar: slides away when hidden, fades with Reduce '
      'Motion; hidden takes no taps', (tester) async {
    var taps = 0;
    Widget bar(bool visible, {bool reduce = false}) => app(
      Align(
        alignment: Alignment.bottomCenter,
        child: DkViewerBar(
          visible: visible,
          actions: [
            for (final a in actions)
              DkBarAction(
                icon: a.icon,
                label: a.label,
                onPressed: () => taps++,
              ),
          ],
        ),
      ),
      reduceMotion: reduce,
    );
    await tester.pumpWidget(bar(true));
    await tester.tap(find.text('Move'));
    expect(taps, 1);
    await tester.pumpWidget(bar(false));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
      const Offset(0, 1),
    );
    await tester.tap(find.text('Move'), warnIfMissed: false);
    expect(taps, 1, reason: 'hidden: no taps');
    await tester.pumpWidget(bar(false, reduce: true));
    await tester.pumpAndSettle();
    expect(find.byType(AnimatedSlide), findsNothing);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );
  });

  testWidgets('camera bar: flash cycles Off → On → Auto, Auto toggles, '
      'labels in EN and DE', (tester) async {
    for (final (locale, flash, auto) in [
      (const Locale('en'), 'Flash: Off', 'Auto-capture'),
      (const Locale('de'), 'Blitz: Aus', 'Automatisch auslösen'),
    ]) {
      final handle = tester.ensureSemantics();
      final flashes = <DkFlash>[];
      final autos = <bool>[];
      await tester.pumpWidget(
        app(
          DkCameraTopBar(
            onClose: _none,
            flash: DkFlash.off,
            onFlash: flashes.add,
            autoCapture: false,
            onAutoCapture: autos.add,
            grid: false,
            onGrid: (_) {},
            onSettings: _none,
          ),
          locale: locale,
        ),
      );
      await tester.tap(find.bySemanticsLabel(flash));
      await tester.tap(find.bySemanticsLabel(auto));
      expect(flashes, [DkFlash.on]);
      expect(autos, [true]);
      expect(
        tester.getSemantics(find.bySemanticsLabel(auto)),
        isSemantics(
          label: auto,
          isButton: true,
          hasToggledState: true,
          isToggled: false,
        ),
      );
      handle.dispose();
    }
  });
}
