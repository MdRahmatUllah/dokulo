import 'package:app_pdf/catalogue/feedback_states.dart';
import 'package:app_pdf/components/dk_action_bar.dart';
import 'package:app_pdf/components/dk_button.dart';
import 'package:app_pdf/components/dk_empty_state.dart';
import 'package:app_pdf/components/dk_illustration.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
    'action_bar': const ActionBarStates(),
    'empty_state': const EmptyStateStates(),
  };
  for (final MapEntry(key: what, value: gallery) in galleries.entries) {
    for (final (name, tokens) in [
      ('light', DkTokens.light),
      ('dark', DkTokens.dark),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$what, $name, ${(scale * 100).round()} %', (tester) async {
          // The empty states are three tall columns.
          final tall = what == 'empty_state';
          tester.view.physicalSize = Size(
            393,
            (tall ? 1300 : 900) * (scale == 1 ? 1 : 2),
          );
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

  group('DkActionBar (DK-0170)', () {
    testWidgets('a large full-width button, 16 / 12 padding, the hairline', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: dokuloTheme(DkTokens.light),
          home: const Scaffold(
            bottomNavigationBar: DkActionBar(
              label: 'Compress 12 pages',
              onPressed: _tap,
              caption: 'About 1.9 MB · 12 pages',
            ),
          ),
        ),
      );
      final bar = tester.getRect(find.byType(DkActionBar));
      final button = tester.getRect(find.byType(DkButton));
      expect(button.width, 393 - 32);
      expect(button.height, greaterThanOrEqualTo(52));
      expect(bar.bottom - button.bottom, 12); // no safe area in tests
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(DkActionBar),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        (box.decoration as BoxDecoration).border,
        Border(top: BorderSide(color: DkTokens.light.color.outline)),
      );
      // Tabular figures in the caption.
      final caption = tester.widget<Text>(find.text('About 1.9 MB · 12 pages'));
      expect(
        caption.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });
  });

  group('DkEmptyState (DK-0196)', () {
    testWidgets('120 illustration, decorative; title, body and buttons', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var moved = 0;
      await tester.pumpWidget(
        app(
          SizedBox(
            height: 600,
            child: DkEmptyState(
              illustration: DkIllustrations.folderEmpty,
              title: 'This folder is empty',
              body: 'Move files here.',
              action: 'Move files here',
              onAction: () => moved++,
            ),
          ),
        ),
      );
      await settle(tester);
      expect(tester.getSize(find.byType(DkIllustration)).height, 120);
      expect(find.bySemanticsLabel('Empty folder'), findsNothing);
      await tester.tap(find.text('Move files here'));
      expect(moved, 1);
      handle.dispose();
    });
  });
  testWidgets('the action bar rides on top of the keyboard', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: dokuloTheme(DkTokens.light),
        home: const Scaffold(
          body: TextField(autofocus: true),
          bottomNavigationBar: DkActionBar(label: 'Rename', onPressed: _tap),
        ),
      ),
    );
    await tester.pump();
    final button = tester.getRect(find.byType(DkButton));
    expect(button.bottom, lessThanOrEqualTo(852 - 300));
  });

  testWidgets('side by side at 100 %, stacked from 150 %; the button is a '
      'button for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    for (final (scale, beside) in [(1.0, true), (1.5, false)]) {
      await tester.pumpWidget(
        app(
          const DkActionBar(
            label: 'Save',
            onPressed: _tap,
            secondaryLabel: 'Review',
            onSecondary: _tap,
            secondaryBeside: true,
          ),
          textScale: scale,
        ),
      );
      final save = tester.getCenter(find.text('Save'));
      final review = tester.getCenter(find.text('Review'));
      expect(save.dy == review.dy, beside, reason: 'at ${scale * 100} %');
    }
    expect(
      tester.getSemantics(find.bySemanticsLabel('Save')),
      isSemantics(label: 'Save', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('empty state: the title is a heading, buttons are 48 dp, the '
      'illustration has no semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      app(
        const SizedBox(
          height: 600,
          child: DkEmptyState(
            illustration: DkIllustrations.folderEmpty,
            title: 'This folder is empty',
            body: 'Move files here.',
            action: 'Move files here',
            onAction: _tap,
            secondaryAction: 'Scan a document',
            onSecondaryAction: _tap,
          ),
        ),
      ),
    );
    await settle(tester);
    expect(
      tester.getSemantics(find.text('This folder is empty')),
      isSemantics(label: 'This folder is empty', isHeader: true),
    );
    for (final b in tester.widgetList<DkButton>(find.byType(DkButton))) {
      expect(tester.getSize(find.byWidget(b)).height, greaterThanOrEqualTo(48));
    }
    expect(
      tester.widget<SvgPicture>(find.byType(SvgPicture)).excludeFromSemantics,
      isTrue,
    );
    handle.dispose();
  });
}

void _tap() {}
