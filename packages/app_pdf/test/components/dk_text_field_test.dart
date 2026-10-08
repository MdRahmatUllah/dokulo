import 'package:app_pdf/components/dk_text_field.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/catalogue/text_field_states.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(
  Widget child, {
  DkTokens? tokens,
  double scale = 1,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
  locale: locale,
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

OutlineInputBorder borderOf(WidgetTester tester, {bool focused = false}) {
  final d = tester.widget<TextField>(find.byType(TextField)).decoration!;
  return (focused ? d.focusedBorder : d.enabledBorder)! as OutlineInputBorder;
}

void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final (lang, scale) in [('en', 1.0), ('en', 2.0), ('de', 2.0)]) {
      final name = '${theme}_${lang}_${(scale * 100).round()}';
      testWidgets('golden: $name', (tester) async {
        tester.view.physicalSize = Size(393, scale > 1 ? 1600 : 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            const SingleChildScrollView(child: DkTextFieldGallery()),
            tokens: tokens,
            scale: scale,
            locale: Locale(lang),
          ),
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/dk_text_fields_$name.png'),
        );
      });
    }
  }

  group('DkTextField (DK-0120)', () {
    testWidgets('48 tall on surfaceSunken, 1 dp outlineStrong, 2 dp primary '
        'focused', (tester) async {
      await tester.pumpWidget(app(const DkTextField(label: 'Name')));
      expect(tester.getSize(find.byType(TextField)).height, 48);
      final c = DkTokens.light.color;
      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration!.fillColor,
        c.surfaceSunken,
      );
      expect(borderOf(tester).borderSide, BorderSide(color: c.outlineStrong));
      expect(
        borderOf(tester, focused: true).borderSide,
        BorderSide(color: c.primary, width: 2),
      );
      expect(
        borderOf(tester).borderRadius,
        BorderRadius.circular(DkTokens.light.radius.s),
      );
    });

    testWidgets('an error: 2 dp danger border, the error icon and message, '
        'read with the field', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(const DkTextField(label: 'Pages', error: 'Page 40 doesn’t exist.')),
      );
      final c = DkTokens.light.color;
      expect(
        borderOf(tester).borderSide,
        BorderSide(color: c.danger, width: 2),
      );
      expect(find.text('Page 40 doesn’t exist.'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(TextField)).label,
        allOf(contains('Pages'), contains('Page 40 doesn’t exist.')),
      );
      handle.dispose();
    });

    testWidgets('the clear button shows while there is text and empties it', (
      tester,
    ) async {
      final text = TextEditingController();
      addTearDown(text.dispose);
      String? changed;
      await tester.pumpWidget(
        app(DkTextField(controller: text, onChanged: (v) => changed = v)),
      );
      expect(find.bySemanticsLabel('Clear'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Rechnung');
      await tester.pump();
      expect(find.bySemanticsLabel('Clear'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Clear'));
      await tester.pump();
      expect(text.text, isEmpty);
      expect(changed, '');
      expect(find.bySemanticsLabel('Clear'), findsNothing);
    });
  });

  group('DkPasswordField (DK-0122)', () {
    testWidgets('hidden until revealed; the toggle says what it does', (
      tester,
    ) async {
      await tester.pumpWidget(app(const DkPasswordField(label: 'Password')));
      bool obscured() =>
          tester.widget<TextField>(find.byType(TextField)).obscureText;
      expect(obscured(), isTrue);
      await tester.tap(find.bySemanticsLabel('Show password'));
      await tester.pump();
      expect(obscured(), isFalse);
      expect(find.bySemanticsLabel('Hide password'), findsOneWidget);
    });

    test('strength: length and variety', () {
      expect(DkPasswordStrength.of(''), isNull);
      expect(DkPasswordStrength.of('abc'), DkPasswordStrength.weak);
      expect(DkPasswordStrength.of('abcdefgh'), DkPasswordStrength.weak);
      expect(DkPasswordStrength.of('abcdefg1'), DkPasswordStrength.fair);
      expect(DkPasswordStrength.of('Abcdefg1'), DkPasswordStrength.good);
      expect(
        DkPasswordStrength.of('Wolke-Tisch-42-Bahn'),
        DkPasswordStrength.strong,
      );
    });

    testWidgets('the meter: segments and the word in the matching colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          const DkPasswordField(showStrength: true),
          locale: const Locale('de'),
        ),
      );
      expect(find.text('Schwach'), findsNothing, reason: 'empty: no meter');
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      final c = DkTokens.light.color;
      expect(tester.widget<Text>(find.text('Schwach')).style!.color, c.danger);
      await tester.enterText(find.byType(TextField), 'Wolke-Tisch-42-Bahn');
      await tester.pump();
      expect(tester.widget<Text>(find.text('Stark')).style!.color, c.success);
    });
  });

  testWidgets('a new error is announced at once', (tester) async {
    Widget field(String? error) =>
        app(DkTextField(label: 'File name', error: error));
    await tester.pumpWidget(field(null));
    expect(tester.takeAnnouncements(), isEmpty);
    await tester.pumpWidget(field('Use a shorter name'));
    expect(
      tester.takeAnnouncements(),
      contains(isAccessibilityAnnouncement('Use a shorter name')),
    );
    // The same error again isn't repeated.
    await tester.pumpWidget(field('Use a shorter name'));
    expect(tester.takeAnnouncements(), isEmpty);
  });

  testWidgets('the field buttons are 48 dp targets with labels', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    // Away from the screen's edges: the guideline skips nodes that touch
    // them.
    await tester.pumpWidget(
      app(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              DkTextField(
                label: 'Name',
                controller: TextEditingController(text: 'abc'),
              ),
              const DkPasswordField(label: 'Password'),
            ],
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).last, 'secret');
    await tester.pump();
    for (final label in ['Clear', 'Show password']) {
      expect(
        tester.getSize(find.bySemanticsLabel(label).first),
        const Size(48, 48),
      );
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
