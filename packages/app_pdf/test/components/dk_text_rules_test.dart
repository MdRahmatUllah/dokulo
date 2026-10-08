import 'package:app_pdf/components/dk_text_rules.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('middleEllipsis', () {
    // A fake measure: n characters (graphemes) fit.
    bool Function(String) upTo(int n) =>
        (s) => s.characters.length <= n;

    test('keeps a name that fits', () {
      expect(middleEllipsis('Rechnung.pdf', fits: upTo(40)), 'Rechnung.pdf');
    });

    test('cuts in the middle and keeps the end and the extension', () {
      final out = middleEllipsis(
        'Mietvertrag_Musterstraße_12_2026.pdf',
        fits: upTo(24),
      );
      expect(out.characters.length, 24);
      expect(out, startsWith('Mietvertrag_'));
      expect(out, endsWith('_2026.pdf'));
      expect(out, contains('…'));
    });

    test('a very narrow space still shows the extension', () {
      expect(middleEllipsis('Kontoauszug-Oktober.pdf', fits: upTo(5)), '….pdf');
    });

    test('never splits an emoji, an accent or an Arabic letter', () {
      for (final name in [
        'Urlaub 👨‍👩‍👧‍👦👨‍👩‍👧‍👦👨‍👩‍👧‍👦 Fotos.pdf',
        'Café Crème Résumé Noël.pdf',
        'عقد الإيجار للشقة الجديدة.pdf',
      ]) {
        for (var n = 5; n < name.characters.length; n++) {
          final out = middleEllipsis(name, fits: upTo(n));
          final kept = out.characters.where((c) => c != '…');
          expect(
            kept.every(name.characters.contains),
            isTrue,
            reason: '$name at $n: $out',
          );
          expect(out, endsWith('.pdf'));
        }
      }
    });
  });

  Widget app(Widget child, {double scale = 1}) => MaterialApp(
    theme: dokuloTheme(DkTokens.light),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: child),
    ),
  );

  testWidgets('the widget fits its width, also at 200 %, and reads the whole '
      'name', (tester) async {
    const name = 'Mietvertrag_Musterstraße_12_2026.pdf';
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(
        app(
          const Center(
            child: SizedBox(width: 160, child: DkMiddleEllipsisText(name)),
          ),
          scale: scale,
        ),
      );
      final shown = tester.widget<Text>(find.byType(Text)).data!;
      expect(shown, endsWith('.pdf'));
      expect(shown, contains('…'));
      expect(tester.takeException(), isNull, reason: 'no overflow');
      expect(find.bySemanticsLabel(name), findsOneWidget);
    }
  });

  testWidgets('body text is at most 640 dp wide on a tablet', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        const DkReadableWidth(
          child: SizedBox(key: Key('text'), height: 20, width: double.infinity),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('text'))).width, 640);
  });
}
