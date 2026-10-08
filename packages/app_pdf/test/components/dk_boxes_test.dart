import 'package:app_pdf/catalogue/page_states.dart';
import 'package:app_pdf/components/dk_box_frame.dart';
import 'package:app_pdf/components/dk_redaction_box.dart';
import 'package:app_pdf/components/dk_signature_stamp.dart';
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
    child: Scaffold(body: child),
  ),
);

/// One box on a page that keeps the rect it is given back.
class _Page extends StatefulWidget {
  const _Page({required this.build});
  final Widget Function(Rect rect, ValueChanged<Rect> onChanged) build;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  Rect rect = const Rect.fromLTWH(100, 100, 120, 40);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 393,
    height: 500,
    child: Stack(
      children: [widget.build(rect, (r) => setState(() => rect = r))],
    ),
  );
}

void main() {
  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final (lang, scale) in [('en', 1.0), ('en', 2.0), ('de', 2.0)]) {
      final file = 'boxes_${name}_${lang}_${(scale * 100).round()}';
      testWidgets('golden: $file', (tester) async {
        tester.view.physicalSize = const Size(393, 332);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            const BoxStates(),
            tokens: tokens,
            textScale: scale,
            locale: Locale(lang),
          ),
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(BoxStates),
          matchesGoldenFile('goldens/$file.png'),
        );
      });
    }
  }

  testWidgets('a selected box moves with the finger and resizes by a corner', (
    tester,
  ) async {
    late Rect rect;
    await tester.pumpWidget(
      app(
        _Page(
          build: (r, onChanged) {
            rect = r;
            return DkRedactionBox(
              rect: r,
              category: 'IBAN',
              selected: true,
              onChanged: onChanged,
              onDelete: () {},
            );
          },
        ),
      ),
    );
    // Move: drag the middle.
    await tester.drag(find.byType(DkRedactionBox), const Offset(30, 20));
    await tester.pump();
    expect(rect, const Rect.fromLTWH(130, 120, 120, 40));
    // Resize: the bottom-right handle, centred on that corner.
    final box =
        tester.getTopLeft(find.byType(DkRedactionBox)) +
        const Offset(DkBoxFrame.margin, DkBoxFrame.margin);
    final gesture = await tester.startGesture(box + const Offset(120, 40));
    await gesture.moveBy(const Offset(20, 0));
    await gesture.moveBy(const Offset(20, 10));
    await gesture.up();
    await tester.pump();
    expect(rect, const Rect.fromLTWH(130, 120, 160, 50));
  });

  testWidgets('a signature keeps its shape while resizing', (tester) async {
    late Rect rect;
    await tester.pumpWidget(
      app(
        _Page(
          build: (r, onChanged) {
            rect = r;
            return DkSignatureStamp(
              rect: r,
              signature: const CatalogueSignature(),
              selected: true,
              onChanged: onChanged,
            );
          },
        ),
      ),
    );
    final origin =
        tester.getTopLeft(find.byType(DkSignatureStamp)) +
        const Offset(DkBoxFrame.margin, DkBoxFrame.margin);
    // The top-right handle (no ×, so it is there): wider and lower.
    final gesture = await tester.startGesture(origin + const Offset(120, 0));
    await gesture.moveBy(const Offset(10, 0));
    await gesture.moveBy(const Offset(50, 0));
    await gesture.up();
    await tester.pump();
    // 3 : 1 kept; the bottom-left corner stayed.
    expect(rect.width / rect.height, closeTo(3, 0.001));
    expect(rect.width, 180);
    expect(rect.bottomLeft, const Offset(100, 140));
  });

  testWidgets('the ×: a 44 target, it deletes; unselected or applied there '
      'are no handles', (tester) async {
    var deleted = 0;
    await tester.pumpWidget(
      app(
        _Page(
          build: (r, onChanged) => DkRedactionBox(
            rect: r,
            category: 'IBAN',
            selected: true,
            onChanged: onChanged,
            onDelete: () => deleted++,
          ),
        ),
      ),
    );
    final remove = find.bySemanticsLabel('Remove box');
    expect(tester.getSize(remove), const Size(44, 44));
    await tester.tap(remove);
    expect(deleted, 1);

    await tester.pumpWidget(
      app(
        const Stack(
          children: [
            DkRedactionBox(
              rect: Rect.fromLTWH(10, 10, 80, 16),
              category: 'IBAN',
            ),
            DkRedactionBox(
              rect: Rect.fromLTWH(10, 60, 80, 16),
              category: 'IBAN',
              applied: true,
            ),
          ],
        ),
      ),
    );
    expect(find.bySemanticsLabel('Remove box'), findsNothing);
    // The applied box is plain black: no tag.
    expect(find.text('IBAN'), findsOneWidget);
  });

  testWidgets('screen readers, EN and DE', (tester) async {
    final handle = tester.ensureSemantics();
    for (final (locale, box, remove, sig, sigRemove) in [
      (
        const Locale('en'),
        'Black-out box: IBAN',
        'Remove box',
        'Signature',
        'Remove signature',
      ),
      (
        const Locale('de'),
        'Schwärzungsfeld: IBAN',
        'Feld entfernen',
        'Unterschrift',
        'Unterschrift entfernen',
      ),
    ]) {
      await tester.pumpWidget(
        app(
          Stack(
            children: [
              DkRedactionBox(
                rect: const Rect.fromLTWH(40, 40, 120, 16),
                category: 'IBAN',
                selected: true,
                onTap: () {},
                onDelete: () {},
              ),
              DkSignatureStamp(
                rect: const Rect.fromLTWH(40, 200, 120, 40),
                signature: const CatalogueSignature(),
                onTap: () {},
                onDelete: () {},
              ),
            ],
          ),
          locale: locale,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(box)),
        isSemantics(label: box, isSelected: true, isButton: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(remove)),
        isSemantics(label: remove, isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(sig)),
        isSemantics(label: sig, isSelected: false),
      );
      // Unselected: no × yet.
      expect(find.bySemanticsLabel(sigRemove), findsNothing);
    }
    handle.dispose();
  });
}
