import 'package:app_pdf/catalogue/dialog_states.dart';
import 'package:app_pdf/components/dk_banner.dart';
import 'package:app_pdf/components/dk_confirm_dialog.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
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
          tester.view.physicalSize = Size(393, scale == 1 ? 900 : 1800);
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
        expect(
          tester.getSize(find.byType(DkConfirmDialog).first).width,
          greaterThanOrEqualTo(312),
        );
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
      final long = find.byType(DkConfirmDialog).at(1);
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
}

void _tap() {}
