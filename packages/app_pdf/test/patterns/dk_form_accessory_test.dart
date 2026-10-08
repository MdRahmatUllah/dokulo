import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/patterns/dk_form_accessory.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<FocusNode> fields;

  Widget form({Locale locale = const Locale('en')}) => MaterialApp(
    theme: dokuloTheme(DkTokens.light),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: DkFormAccessory(
        child: Column(
          children: [for (final f in fields) TextField(focusNode: f)],
        ),
      ),
    ),
  );

  setUp(() => fields = List.generate(3, (_) => FocusNode()));
  tearDown(() {
    for (final f in fields) {
      f.dispose();
    }
  });

  void keyboard(WidgetTester tester, {required bool open}) {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: open ? 300 : 0);
    addTearDown(tester.view.reset);
  }

  testWidgets('the bar shows only while the keyboard is open', (tester) async {
    keyboard(tester, open: false);
    await tester.pumpWidget(form());
    expect(find.byType(DkFormAccessoryBar), findsNothing);
    keyboard(tester, open: true);
    await tester.pump();
    expect(find.byType(DkFormAccessoryBar), findsOneWidget);
    // Right on top of the keyboard.
    expect(tester.getRect(find.byType(DkFormAccessoryBar)).bottom, 852 - 300);
  });

  testWidgets('Next, Previous and Done move the focus; the keyboard stays', (
    tester,
  ) async {
    keyboard(tester, open: true);
    await tester.pumpWidget(form());
    fields[0].requestFocus();
    await tester.pump();
    await tester.tap(find.text('Next field'));
    await tester.pump();
    expect(fields[1].hasFocus, isTrue);
    await tester.tap(find.byTooltip('Previous field'));
    await tester.pump();
    expect(fields[0].hasFocus, isTrue);
    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(fields.any((f) => f.hasFocus), isFalse);
  });

  testWidgets('tap targets and labels; German', (tester) async {
    keyboard(tester, open: true);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(form(locale: const Locale('de')));
    expect(find.text('Nächstes Feld'), findsOneWidget);
    expect(find.text('Fertig'), findsOneWidget);
    expect(find.byTooltip('Vorheriges Feld'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('Next and Previous field skip a checkbox and a button', (
    tester,
  ) async {
    keyboard(tester, open: true);
    var on = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: dokuloTheme(DkTokens.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DkFormAccessory(
            child: StatefulBuilder(
              builder: (context, set) => Column(
                children: [
                  TextField(focusNode: fields[0]),
                  Checkbox(value: on, onChanged: (v) => set(() => on = v!)),
                  TextButton(onPressed: () {}, child: const Text('Paste')),
                  TextField(focusNode: fields[1]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    fields[0].requestFocus();
    await tester.pump();
    await tester.tap(find.text('Next field'));
    await tester.pump();
    expect(fields[1].hasFocus, isTrue);
    await tester.tap(find.byTooltip('Previous field'));
    await tester.pump();
    expect(fields[0].hasFocus, isTrue);
  });
}
