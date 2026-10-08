import 'package:app_pdf/catalogue/overlay_states.dart';
import 'package:app_pdf/components/dk_sheet.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child, {DkTokens? tokens, double textScale = 1}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dokuloTheme(tokens ?? DkTokens.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Scaffold(body: child),
      ),
    );

/// A button that opens a sheet with [open], for the behaviour tests.
Widget opener(void Function(BuildContext) open) => Builder(
  builder: (context) => Center(
    child: TextButton(
      onPressed: () => open(context),
      child: const Text('open'),
    ),
  ),
);

void phone(WidgetTester tester, [Size size = const Size(393, 852)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('the sheet, $name, ${(scale * 100).round()} %', (
        tester,
      ) async {
        phone(tester, Size(393, scale == 1 ? 520 : 900));
        await tester.pumpWidget(
          app(const SheetStates(), tokens: tokens, textScale: scale),
        );
        await expectLater(
          find.byType(DkSheet),
          matchesGoldenFile(
            'goldens/sheet_${name}_${(scale * 100).round()}.png',
          ),
        );
      });
    }
  }

  testWidgets('handle 36 × 4, 8 below the top; the × is a labelled 44 target', (
    tester,
  ) async {
    phone(tester);
    var closed = 0;
    await tester.pumpWidget(
      app(
        Align(
          alignment: Alignment.bottomCenter,
          child: DkSheet(
            title: 'Sort by',
            body: const Text('body'),
            onClose: () => closed++,
          ),
        ),
      ),
    );
    final sheet = tester.getRect(find.byType(DkSheet));
    final handle = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.constraints == const BoxConstraints.tightFor(width: 36, height: 4),
    );
    // The Container's rect includes its margin: measure the bar itself.
    final bar = find.descendant(
      of: handle,
      matching: find.byType(DecoratedBox),
    );
    expect(tester.getRect(bar).top - sheet.top, 8);
    expect(tester.getSize(bar), const Size(36, 4));
    final close = find.byTooltip('Close');
    expect(tester.getSize(close), const Size(44, 44));
    await tester.tap(close);
    expect(closed, 1);
  });

  testWidgets('small: as tall as its content; a swipe down closes it', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      app(
        opener(
          (c) =>
              showDkSheet<void>(c, title: 'Sort by', body: const Text('body')),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(DkSheet)).height, lessThan(300));
    await tester.fling(find.text('Sort by'), const Offset(0, 400), 1500);
    await tester.pumpAndSettle();
    expect(find.byType(DkSheet), findsNothing);
  });

  testWidgets('medium opens at half the screen, large at 92 %', (tester) async {
    phone(tester);
    for (final (detent, share) in [
      (DkSheetDetent.medium, 0.5),
      (DkSheetDetent.large, 0.92),
    ]) {
      await tester.pumpWidget(
        app(
          opener(
            (c) => showDkSheet<void>(
              c,
              title: 'Options',
              detent: detent,
              body: const Text('body'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(DkSheet)).height,
        closeTo(852 * share, 1),
      );
      await tester.tapAt(const Offset(196, 20)); // the scrim
      await tester.pumpAndSettle();
    }
  });

  testWidgets('unsaved content: swipe, back and the scrim ask first', (
    tester,
  ) async {
    phone(tester);
    var asked = 0;
    var allow = false;
    await tester.pumpWidget(
      app(
        opener(
          (c) => showDkSheet<void>(
            c,
            title: 'Edit',
            body: const Text('body'),
            confirmDismiss: () async {
              asked++;
              return allow;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.fling(find.text('Edit'), const Offset(0, 300), 1500);
    await tester.pumpAndSettle();
    expect((asked, find.byType(DkSheet).evaluate().length), (1, 1));

    await tester.tapAt(const Offset(196, 20)); // the scrim
    await tester.pumpAndSettle();
    expect((asked, find.byType(DkSheet).evaluate().length), (2, 1));

    allow = true;
    await tester.binding.handlePopRoute(); // Android back
    await tester.pumpAndSettle();
    expect((asked, find.byType(DkSheet).evaluate().length), (3, 0));
  });

  testWidgets('the keyboard pushes the content and actions up', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      app(
        opener(
          (c) => showDkSheet<void>(
            c,
            title: 'Rename',
            body: const TextField(),
            actions: const Text('actions'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final before = tester.getBottomLeft(find.text('actions')).dy;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(before - tester.getBottomLeft(find.text('actions')).dy, 300);
  });

  testWidgets('a tablet shows it as a centred dialog, at most 560 wide', (
    tester,
  ) async {
    phone(tester, const Size(1024, 768));
    await tester.pumpWidget(
      app(
        opener(
          (c) => showDkSheet<void>(c, title: 'Sort by', body: const Text('b')),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    final rect = tester.getRect(find.byType(DkSheet));
    expect(rect.width, lessThanOrEqualTo(560));
    expect(rect.center.dx, closeTo(512, 1));
  });
}
