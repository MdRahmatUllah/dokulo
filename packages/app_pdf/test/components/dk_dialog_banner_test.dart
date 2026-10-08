import 'package:app_pdf/catalogue/dialog_states.dart';
import 'package:app_pdf/components/dk_banner.dart';
import 'package:app_pdf/components/dk_button.dart';
import 'package:app_pdf/components/dk_confirm_dialog.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(
  Widget child, {
  DkTokens? tokens,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery.withClampedTextScaling(
    minScaleFactor: textScale,
    maxScaleFactor: textScale,
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

/// SVGs decode off the test clock.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  final galleries = <String, Widget>{
    'confirm_dialog': const ConfirmDialogStates(),
    'banner': const BannerStates(),
  };
  for (final MapEntry(key: what, value: gallery) in galleries.entries) {
    for (final (name, tokens) in [
      ('light', DkTokens.light),
      ('dark', DkTokens.dark),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$what, $name, ${(scale * 100).round()} %', (tester) async {
          tester.view.physicalSize = Size(393, scale == 1 ? 1500 : 2900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            app(gallery, tokens: tokens, textScale: scale),
          );
          await settle(tester);
          await expectLater(
            find.byWidget(gallery),
            matchesGoldenFile(
              'goldens/${what}_${name}_${(scale * 100).round()}.png',
            ),
          );
        });
      }
    }
  }

  group('DkConfirmDialog (DK-0186)', () {
    testWidgets('min(320, screen − 48) wide; true only for the action', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final answers = <bool>[];
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => answers.add(
                await showDkConfirm(
                  context,
                  title: 'Delete 3 files for good?',
                  action: 'Delete for good',
                  destructive: true,
                ),
              ),
              child: const Text('ask'),
            ),
          ),
        ),
      );
      for (final tap in ['Delete for good', 'Cancel', null]) {
        await tester.tap(find.text('ask'));
        await tester.pumpAndSettle();
        // The card itself: min(320, 360 − 48) = 312.
        final card = find.descendant(
          of: find.byType(DkConfirmDialog),
          matching: find.byType(Container),
        );
        expect(tester.getSize(card.first).width, 312);
        if (tap == null) {
          await tester.tapAt(const Offset(10, 10)); // outside
        } else {
          await tester.tap(find.text(tap));
        }
        await tester.pumpAndSettle();
      }
      expect(answers, [true, false, false]);
    });

    testWidgets('side by side when they fit, stacked when not; the action '
        'on top', (tester) async {
      // The test font's glyphs are 1 em wide: "Cancel" + "Delete" fit in
      // the 272 inside a 320 dialog, "Replace the original file" doesn't.
      await tester.pumpWidget(
        app(
          const DkConfirmDialog(
            title: 'Delete?',
            action: 'Delete',
            onCancel: _tap,
            onAction: _tap,
          ),
        ),
      );
      final cancel = find.text('Cancel');
      final action = find.text('Delete');
      expect(tester.getCenter(cancel).dy, tester.getCenter(action).dy);
      expect(
        tester.getCenter(cancel).dx,
        lessThan(tester.getCenter(action).dx),
      );

      await tester.pumpWidget(app(const ConfirmDialogStates()));
      final long = find.byType(DkConfirmDialog).at(3);
      final c2 = find.descendant(of: long, matching: find.text('Cancel'));
      final a2 = find.descendant(
        of: long,
        matching: find.text('Replace the original file'),
      );
      expect(tester.getCenter(a2).dy, lessThan(tester.getCenter(c2).dy));
    });

    testWidgets('screen readers: the dialog is named by its title', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app(const ConfirmDialogStates()));
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Delete 3 files for good?').first,
        ),
        isSemantics(scopesRoute: true, namesRoute: true),
      );
      handle.dispose();
    });
  });

  group('DkBanner (DK-0192)', () {
    testWidgets('each kind has its fill and icon; the action works', (
      tester,
    ) async {
      var acted = 0;
      await tester.pumpWidget(
        app(
          DkBanner(
            text: '3 scans have no searchable text yet.',
            action: 'Make searchable',
            onAction: () => acted++,
          ),
        ),
      );
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(DkBanner),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (box.decoration! as BoxDecoration).color,
        DkTokens.light.color.primaryContainer,
      );
      await tester.tap(find.text('Make searchable'));
      expect(acted, 1);
    });
  });
  group('DkConfirmDialog motion, fit, keys and languages', () {
    Widget asker(void Function(bool) answer, {String body = 'x'}) => Builder(
      builder: (context) => TextButton(
        onPressed: () async => answer(
          await showDkConfirm(
            context,
            title: 'Delete 3 files for good?',
            body: body,
            action: 'Delete for good',
            destructive: true,
          ),
        ),
        child: const Text('ask'),
      ),
    );

    testWidgets('opens in 220 ms; 120 ms with Reduce Motion', (tester) async {
      for (final (reduce, ms) in [(false, 220), (true, 120)]) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(disableAnimations: reduce);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await tester.pumpWidget(app(asker((_) {})));
        await tester.tap(find.text('ask'));
        await tester.pump();
        await tester.pump(Duration(milliseconds: ms - 20));
        final route = ModalRoute.of(
          tester.element(find.byType(DkConfirmDialog)),
        )!;
        expect(route.animation!.isCompleted, isFalse, reason: 'reduce $reduce');
        await tester.pump(const Duration(milliseconds: 40));
        expect(route.animation!.isCompleted, isTrue, reason: 'reduce $reduce');
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('iPhone SE, 200 %, German, a long body: it fits and scrolls', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // The dialog's route sits above `home`: set the platform's text size.
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        app(
          asker(
            (_) {},
            body:
                'Diese Dateien werden endgültig gelöscht und lassen sich '
                'nicht wiederherstellen. Auch Kopien in anderen Ordnern '
                'bleiben davon unberührt.',
          ),
          locale: const Locale('de'),
        ),
      );
      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Abbrechen'), findsOneWidget);
      final card = tester.getRect(
        find
            .descendant(
              of: find.byType(DkConfirmDialog),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(card.height, lessThanOrEqualTo(667 - 48));
    });

    testWidgets('Esc says no; buttons are 48 dp targets', (tester) async {
      final answers = <bool>[];
      await tester.pumpWidget(app(asker(answers.add)));
      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      for (final b in tester.widgetList<DkButton>(find.byType(DkButton))) {
        expect(
          tester.getSize(find.byWidget(b)).height,
          greaterThanOrEqualTo(48),
        );
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(answers, [false]);
    });
  });

  group('DkBanner semantics', () {
    testWidgets('the text is read, the action is a 48 dp button; errors are '
        'announced', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(
          Column(
            children: [
              DkBanner(
                text: '3 scans have no searchable text yet.',
                action: 'Make searchable',
                onAction: () {},
              ),
              const DkBanner(
                text: 'This file is damaged.',
                variant: DkBannerVariant.error,
              ),
            ],
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('3 scans have no searchable text yet.'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Make searchable')),
        isSemantics(label: 'Make searchable', isButton: true),
      );
      expect(
        tester.getSize(find.byType(DkButton)).height,
        greaterThanOrEqualTo(48),
      );
      final error = tester.widget<Semantics>(
        find
            .descendant(
              of: find.widgetWithText(DkBanner, 'This file is damaged.'),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(error.properties.liveRegion, isTrue);
      handle.dispose();
    });
  });
}

void _tap() {}
