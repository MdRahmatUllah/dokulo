import 'package:app_pdf/catalogue/progress_states.dart';
import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/components/dk_illustration.dart';
import 'package:app_pdf/components/dk_progress_sheet.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

Widget sheet({
  double progress = 0.45,
  VoidCallback? onCancel,
  VoidCallback? onKeepWorking,
  DkProgressError? error,
}) => Padding(
  padding: const EdgeInsets.all(16),
  child: DkProgressSheet(
    toolIcon: DkIcons.tool('compress'),
    title: 'Compressing Mietvertrag.pdf',
    progress: progress,
    page: 18,
    pageCount: 40,
    timeLeft: '20 s',
    onCancel: onCancel ?? () {},
    onKeepWorking: onKeepWorking ?? () {},
    error: error,
  ),
);

void main() {
  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final (lang, scale) in [('en', 1.0), ('en', 2.0), ('de', 2.0)]) {
      final file = 'progress_sheet_${name}_${lang}_${(scale * 100).round()}';
      testWidgets('golden: $file', (tester) async {
        phone(tester, const Size(393, 1400));
        await tester.pumpWidget(
          app(
            const SingleChildScrollView(child: ProgressSheetStates()),
            tokens: tokens,
            scale: scale,
            locale: Locale(lang),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500)); // the SVG
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(ProgressSheetStates),
          matchesGoldenFile('goldens/$file.png'),
        );
      });
    }
  }

  testWidgets('the parts: 40 tonal icon, a 6 dp bar, the percent, the page '
      'and the time left, in EN and DE', (tester) async {
    phone(tester, const Size(393, 600));
    await tester.pumpWidget(app(sheet()));
    expect(
      tester.getSize(
        find.ancestor(
          of: find.byType(DkIcon).first,
          matching: find.byType(Container),
        ),
      ),
      const Size(40, 40),
    );
    expect(tester.getSize(find.byType(LinearProgressIndicator)).height, 6);
    expect(find.text('45 %'), findsOne);
    expect(find.text('Page 18 of 40 · about 20 s left'), findsOne);
    await tester.pumpWidget(app(sheet(), locale: const Locale('de')));
    expect(find.text('Seite 18 von 40 · noch etwa 20 s'), findsOne);
    expect(find.text('Weiterarbeiten'), findsOne);
  });

  testWidgets('screen readers hear the progress in 25 % steps, live', (
    tester,
  ) async {
    phone(tester, const Size(393, 600));
    final handle = tester.ensureSemantics();
    SemanticsNode bar() => tester.getSemantics(
      find
          .ancestor(
            of: find.byType(LinearProgressIndicator),
            matching: find.byType(Semantics),
          )
          .first,
    );
    for (final (progress, heard) in [
      (0.1, '0 %'),
      (0.3, '25 %'),
      (0.49, '25 %'),
      (0.5, '50 %'),
      (0.99, '75 %'),
      (1.0, '100 %'),
    ]) {
      await tester.pumpWidget(app(sheet(progress: progress)));
      expect(
        bar(),
        isSemantics(
          label: 'Compressing Mietvertrag.pdf',
          value: heard,
          isLiveRegion: true,
        ),
        reason: '$progress',
      );
    }
    handle.dispose();
  });

  testWidgets('Cancel and Keep working: pressable, 48 dp', (tester) async {
    phone(tester, const Size(393, 600));
    final handle = tester.ensureSemantics();
    final taps = <String>[];
    await tester.pumpWidget(
      app(
        sheet(
          onCancel: () => taps.add('cancel'),
          onKeepWorking: () => taps.add('keep'),
        ),
      ),
    );
    await tester.tap(find.text('Cancel'));
    await tester.tap(find.text('Keep working'));
    expect(taps, ['cancel', 'keep']);
    expectPressableButtons(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('failed: ILL-20 at 64, the title, the body and one action', (
    tester,
  ) async {
    phone(tester, const Size(393, 600));
    var retried = 0;
    await tester.pumpWidget(
      app(
        sheet(
          error: DkProgressError(
            title: "Couldn't compress this file",
            body: 'Your original is unchanged.',
            action: 'Try again',
            onAction: () => retried++,
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(DkIllustration)).height, 64);
    expect(find.text("Couldn't compress this file"), findsOne);
    expect(find.text('Cancel'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(find.text('Try again'));
    expect(retried, 1);
  });

  testWidgets('from 150 % text the buttons stack, Keep working on top', (
    tester,
  ) async {
    phone(tester, const Size(393, 900));
    await tester.pumpWidget(app(sheet(), scale: 1.5));
    final keep = tester.getRect(find.text('Keep working'));
    final cancel = tester.getRect(find.text('Cancel'));
    expect(keep.bottom, lessThan(cancel.top));
    await tester.pumpWidget(app(sheet()));
    expect(
      tester.getCenter(find.text('Keep working')).dy,
      tester.getCenter(find.text('Cancel')).dy,
    );
  });
}
