import 'package:app_pdf/catalogue/sign_states.dart';
import 'package:app_pdf/components/dk_signature_card.dart';
import 'package:app_pdf/components/dk_split_marker.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

void main() {
  final galleries = <String, Widget>{
    'signature_card': const SignatureCardStates(),
    'split': const SplitStates(),
  };
  for (final MapEntry(key: what, value: gallery) in galleries.entries) {
    for (final (name, tokens) in [
      ('light', DkTokens.light),
      ('dark', DkTokens.dark),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$what, $name, ${(scale * 100).round()} %', (tester) async {
          tester.view.physicalSize = Size(393, scale == 1 ? 400 : 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            app(gallery, tokens: tokens, textScale: scale),
          );
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

  testWidgets('DkSignatureCard: 160 × 72 on white; tap places, long-press '
      'deletes; the delete action for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    final done = <String>[];
    await tester.pumpWidget(
      app(
        DkSignatureCard(
          signature: const Text('MM'),
          onTap: () => done.add('place'),
          onDelete: () => done.add('delete'),
        ),
      ),
    );
    final card = find.byType(DkSignatureCard);
    expect(tester.getSize(card), const Size(160, 72));
    await tester.tap(card);
    await tester.longPress(card);
    expect(done, ['place', 'delete']);
    final node = tester.getSemantics(find.bySemanticsLabel('Saved signature'));
    final actions = node.getSemanticsData().customSemanticsActionIds!;
    expect(actions.map((id) => CustomSemanticsAction.getAction(id)!.label), [
      'Delete signature',
    ]);
    handle.dispose();
  });

  testWidgets('DkSplitMarker removes a cut, DkSplitGap adds one; both are '
      'labelled', (tester) async {
    final handle = tester.ensureSemantics();
    final done = <String>[];
    await tester.pumpWidget(
      app(
        Column(
          children: [
            DkSplitMarker(
              reason: 'New letterhead',
              onRemove: () => done.add('remove'),
            ),
            DkSplitGap(height: 50, onSplit: () => done.add('split')),
          ],
        ),
      ),
    );
    expect(tester.getSize(find.byType(DkSplitMarker)).height, 48);
    await tester.tap(find.byType(DkSplitMarker));
    await tester.tap(find.byType(DkSplitGap));
    expect(done, ['remove', 'split']);
    expect(
      find.bySemanticsLabel("Don't split here, New letterhead"),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Split here'), findsOneWidget);
    handle.dispose();
  });
}
