import 'package:app_pdf/catalogue/option_row_states.dart';
import 'package:app_pdf/components/dk_switch.dart';
import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/components/dk_option_row.dart';
import 'package:app_pdf/components/dk_position_picker.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(
  Widget child, {
  DkTokens? tokens,
  double scale = 1,
  Locale locale = const Locale('en'),
  bool reduce = false,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: reduce),
    child: app!,
  ),
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final (lang, scale) in [('en', 1.0), ('en', 2.0), ('de', 2.0)]) {
      final name = '${theme}_${lang}_${(scale * 100).round()}';
      testWidgets('golden: $name', (tester) async {
        tester.view.physicalSize = Size(393, scale > 1 ? 1100 : 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            const SingleChildScrollView(child: DkOptionRowGallery()),
            tokens: tokens,
            scale: scale,
            locale: Locale(lang),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/dk_option_row_$name.png'),
        );
      });
    }
  }

  group('DkOptionRow and More options (DK-0138)', () {
    testWidgets('12 dp padding, a divider, help capped at 2 lines; the '
        'switch reads with its title', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(
          DkOptionRow(
            title: 'Keep bookmarks',
            help: 'A long help text ' * 20,
            control: DkSwitch(value: true, onChanged: (_) {}),
          ),
        ),
      );
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(DkOptionRow),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(box.padding, const EdgeInsets.symmetric(vertical: 12));
      expect(
        (box.decoration! as BoxDecoration).border,
        Border(bottom: BorderSide(color: DkTokens.light.color.outline)),
      );
      expect(
        tester.widget<Text>(find.textContaining('A long help')).maxLines,
        2,
      );
      expect(
        tester.getSemantics(find.byType(Switch)).label,
        contains('Keep bookmarks'),
      );
      handle.dispose();
    });

    testWidgets('More options opens and closes', (tester) async {
      await tester.pumpWidget(
        app(const DkMoreOptions(children: [Text('Hidden option')])),
      );
      expect(find.text('Hidden option'), findsNothing);
      await tester.tap(find.text('More options'));
      await tester.pumpAndSettle();
      expect(find.text('Hidden option'), findsOneWidget);
      expect(find.byIcon(DkIcons.expandLess), findsOneWidget);
    });
  });

  group('DkPositionPicker (DK-0140)', () {
    testWidgets('120 × 160, six 28 dp targets, each announced; centre on '
        'request', (tester) async {
      DkPagePosition? picked;
      await tester.pumpWidget(
        app(
          Align(
            alignment: Alignment.topLeft,
            child: DkPositionPicker(
              selected: DkPagePosition.bottomCentre,
              onChanged: (p) => picked = p,
            ),
          ),
          locale: const Locale('de'),
        ),
      );
      expect(
        tester.getSize(find.byType(DkPositionPicker)),
        const Size(120, 160),
      );
      for (final label in [
        'Oben links',
        'Oben Mitte',
        'Oben rechts',
        'Unten links',
        'Unten Mitte',
        'Unten rechts',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
      expect(find.bySemanticsLabel('Mitte'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Oben rechts'));
      expect(picked, DkPagePosition.topRight);
      final dot = tester.widget<Container>(
        find
            .descendant(
              of: find.bySemanticsLabel('Unten Mitte'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(dot.constraints!.maxWidth, 28);
      expect(
        (dot.decoration! as BoxDecoration).color,
        DkTokens.light.color.primary,
      );
    });
  });
}
