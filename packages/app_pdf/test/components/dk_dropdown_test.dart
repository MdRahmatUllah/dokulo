import 'package:app_pdf/catalogue/dropdown_states.dart';
import 'package:app_pdf/components/dk_dropdown.dart';
import 'package:app_pdf/components/dk_ring.dart';
import 'package:app_pdf/components/dk_sheet.dart';
import 'package:app_pdf/theme/dk_layout.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child, {DkTokens? tokens, double scale = 1}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: app!,
  ),
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

const languages = [('auto', 'Auto'), ('de', 'German'), ('en', 'English')];
const many = [
  ('de', 'German'),
  ('en', 'English'),
  ('fr', 'French'),
  ('es', 'Spanish'),
  ('it', 'Italian'),
  ('pl', 'Polish'),
  ('tr', 'Turkish'),
];

void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final scale in [1.0, 2.0]) {
      final name = '${theme}_${(scale * 100).round()}';
      testWidgets('golden: $name', (tester) async {
        tester.view.physicalSize = Size(393, scale > 1 ? 700 : 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(const DkDropdownGallery(), tokens: tokens, scale: scale),
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/dk_dropdown_$name.png'),
        );
      });
    }
  }

  testWidgets('up to five options: a menu; picking reports the value', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      app(
        DkDropdown<String>(
          label: 'Language',
          options: languages,
          value: 'auto',
          onChanged: (v) => picked = v,
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(Container).first).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.text('Auto'));
    await tester.pumpAndSettle();
    expect(find.byType(DkSheet), findsNothing);
    // The menu is as wide as the field.
    expect(
      tester
          .getSize(
            find
                .ancestor(
                  of: find.text('English'),
                  matching: find.byType(Container),
                )
                .first,
          )
          .width,
      greaterThanOrEqualTo(
        tester.getSize(find.byType(DkDropdown<String>)).width,
      ),
    );
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(picked, 'en');
  });

  testWidgets('more than five: a bottom sheet', (tester) async {
    String? picked;
    await tester.pumpWidget(
      app(
        DkDropdown<String>(
          options: many,
          value: 'de',
          onChanged: (v) => picked = v,
        ),
      ),
    );
    await tester.tap(find.text('German'));
    await tester.pumpAndSettle();
    expect(find.byType(DkSheet), findsOneWidget);
    await tester.tap(find.text('Polish'));
    await tester.pumpAndSettle();
    expect(picked, 'pl');
  });

  testWidgets('semantics: a button with its label, value and error', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      app(
        DkDropdown<String>(
          label: 'Language',
          options: languages,
          value: 'de',
          onChanged: (_) {},
          error: 'Download German first.',
        ),
      ),
    );
    final node = tester.getSemantics(find.byType(GestureDetector).first);
    expect(node.label, 'Language\nDownload German first.');
    expect(node.value, 'German');
    expect(node.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('disabled: 40 % and it does not open', (tester) async {
    await tester.pumpWidget(
      app(
        const DkDropdown<String>(
          options: languages,
          value: 'en',
          onChanged: null,
        ),
      ),
    );
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Auto'), findsNothing);
    expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 0.4);
  });

  testWidgets('the keyboard reaches it: the ring, Enter opens the menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        DkDropdown<String>(
          label: 'Language',
          options: languages,
          value: 'auto',
          onChanged: (_) {},
        ),
      ),
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (w) => w is DkRing && w.side == DkTokens.light.focusRing,
      ),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget, reason: 'the menu is open');
  });
}
