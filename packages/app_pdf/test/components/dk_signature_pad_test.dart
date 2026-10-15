import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:app_pdf/components/dk_signature_canvas.dart';
import 'package:app_pdf/components/dk_signature_pad.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
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

/// A landscape phone.
void landscape(WidgetTester tester) {
  tester.view.physicalSize = const Size(852, 393);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget pad({
  DkSignatureMode mode = DkSignatureMode.draw,
  String name = '',
  ValueChanged<Uint8List>? onSave,
  VoidCallback? onTakePhoto,
  VoidCallback? onChoosePhoto,
}) => DkSignaturePad(
  initialMode: mode,
  name: name,
  onCancel: () {},
  onSave: (png, _) => onSave?.call(png),
  onTakePhoto: onTakePhoto ?? () {},
  onChoosePhoto: onChoosePhoto ?? () {},
);

void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final mode in DkSignatureMode.values) {
      for (final (lang, scale) in [('en', 1.0), ('en', 2.0), ('de', 2.0)]) {
        final file =
            'signature_pad_${mode.name}_${theme}_${lang}_${(scale * 100).round()}';
        testWidgets('golden: $file', (tester) async {
          landscape(tester);
          await tester.pumpWidget(
            app(
              pad(
                mode: mode,
                name: mode == DkSignatureMode.type ? 'Max Mustermann' : '',
              ),
              tokens: tokens,
              scale: scale,
              locale: Locale(lang),
            ),
          );
          if (mode == DkSignatureMode.draw) {
            await tester.dragFrom(
              const Offset(300, 250),
              const Offset(200, -60),
            );
            await tester.pump();
          }
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(DkSignaturePad),
            matchesGoldenFile('goldens/$file.png'),
          );
        });
      }
    }
  }

  testWidgets('Save is off until something is drawn; then it hands over a '
      'PNG', (tester) async {
    landscape(tester);
    final saved = <Uint8List>[];
    await tester.pumpWidget(app(pad(onSave: saved.add)));
    await tester.tap(find.text('Save'));
    expect(saved, isEmpty);
    await tester.dragFrom(const Offset(300, 250), const Offset(200, -60));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(saved, hasLength(1));
    // Clear empties the canvas, and Save is off again.
    await tester.tap(find.text('Clear'));
    await tester.pump();
    final canvas = tester.widget<DkSignatureCanvas>(
      find.byType(DkSignatureCanvas),
    );
    expect(canvas.controller.isEmpty, isTrue);
  });

  testWidgets('the ink: Black or Blue ink, the chosen one named', (
    tester,
  ) async {
    landscape(tester);
    await tester.pumpWidget(app(pad()));
    DkSignatureController controller() => tester
        .widget<DkSignatureCanvas>(find.byType(DkSignatureCanvas))
        .controller;
    expect(controller().ink, const DkMarkup().black);
    await tester.tap(find.bySemanticsLabel('Blue ink'));
    await tester.pump();
    expect(controller().ink, const DkMarkup().ink);
    expect(find.text('Blue ink'), findsOne);
  });

  testWidgets('Type: a name enables Save; the chosen style is rendered', (
    tester,
  ) async {
    landscape(tester);
    final saved = <Uint8List>[];
    await tester.pumpWidget(
      app(pad(mode: DkSignatureMode.type, onSave: saved.add)),
    );
    await tester.tap(find.text('Save'));
    expect(saved, isEmpty);
    await tester.enterText(find.byType(TextField), 'Max Mustermann');
    await tester.pump();
    expect(find.text('Max Mustermann'), findsNWidgets(4)); // field + 3 styles
    await tester.tap(find.bySemanticsLabel('Handwriting style 2'));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(saved, hasLength(1));
    await tester.runAsync(() async {
      final image = (await (await ui.instantiateImageCodec(
        saved.single,
      )).getNextFrame()).image;
      final rgba = (await image.toByteData())!;
      expect(rgba.getUint8(3), 0, reason: 'transparent around the ink');
      expect(image.width, greaterThan(image.height));
    });
  });

  testWidgets('Image: Take photo and Choose photo go to the screen', (
    tester,
  ) async {
    landscape(tester);
    final taps = <String>[];
    await tester.pumpWidget(
      app(
        pad(
          mode: DkSignatureMode.image,
          onTakePhoto: () => taps.add('take'),
          onChoosePhoto: () => taps.add('choose'),
        ),
      ),
    );
    await tester.tap(find.text('Take photo'));
    await tester.tap(find.text('Choose photo'));
    expect(taps, ['take', 'choose']);
  });

  testWidgets('screen readers and targets, every tab', (tester) async {
    landscape(tester);
    final handle = tester.ensureSemantics();
    for (final mode in DkSignatureMode.values) {
      await tester.pumpWidget(app(pad(mode: mode, name: 'Max Mustermann')));
      expectPressableButtons(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    }
    // The canvas is named; drawing isn't for screen readers (Type is).
    await tester.pumpWidget(app(pad()));
    expect(find.bySemanticsLabel('Sign on the line'), findsOne);
    handle.dispose();
  });
}
