import 'package:app_pdf/catalogue/tool_tile_states.dart';
import 'package:app_pdf/components/dk_pro_badge.dart';
import 'package:app_pdf/components/dk_status_dot.dart';
import 'package:app_pdf/components/dk_tool_tile.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
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
        tester.view.physicalSize = Size(393, scale > 1 ? 900 : 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            const SingleChildScrollView(child: DkToolTileGallery()),
            tokens: tokens,
            scale: scale,
            locale: Locale(lang),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/tool_tile_$name.png'),
        );
      });
    }
  }

  group('DkToolTile (DK-0082)', () {
    testWidgets('96 tall, at least 76 wide; the 48 dp square with a 28 icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          Center(
            child: DkToolTile(toolId: 'compress', onTap: () {}),
          ),
        ),
      );
      final size = tester.getSize(find.byType(DkToolTile));
      expect(size.height, greaterThanOrEqualTo(96));
      expect(size.width, greaterThanOrEqualTo(76));
      expect(tester.widget<Icon>(find.byType(Icon)).size, 28);
      expect(find.text('Compress PDF'), findsOneWidget);
    });

    testWidgets('screen readers: the name, and ", Pro" for a Pro tool', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(
          Row(
            children: [
              DkToolTile(toolId: 'compress', onTap: () {}),
              DkToolTile(toolId: 'redact', onTap: () {}),
            ],
          ),
        ),
      );
      expect(find.bySemanticsLabel('Compress PDF'), findsOneWidget);
      expect(find.bySemanticsLabel('Black out (redact), Pro'), findsOneWidget);
      expect(find.byType(DkProBadge), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the new dot shows for 14 days after the release date', (
      tester,
    ) async {
      Widget tile(DateTime now) => app(
        Center(
          child: DkToolTile(
            toolId: 'merge',
            onTap: () {},
            addedOn: DateTime(2026, 10, 1),
            now: now,
          ),
        ),
      );
      await tester.pumpWidget(tile(DateTime(2026, 10, 14)));
      expect(find.byType(DkStatusDot), findsOneWidget);
      await tester.pumpWidget(tile(DateTime(2026, 10, 16)));
      expect(find.byType(DkStatusDot), findsNothing);
    });

    testWidgets('tap, long press and the keyboard', (tester) async {
      var taps = 0, menus = 0;
      await tester.pumpWidget(
        app(
          Center(
            child: DkToolTile(
              toolId: 'merge',
              onTap: () => taps++,
              onLongPress: () => menus++,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(DkToolTile));
      await tester.longPress(find.byType(DkToolTile));
      expect((taps, menus), (1, 1));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(taps, 2);
    });
  });

  group('DkToolRow (DK-0084)', () {
    testWidgets('56 tall, the 40 dp square, the description, the Pro badge', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        app(
          Column(
            children: [
              DkToolRow(toolId: 'merge', onTap: () => taps++),
              DkToolRow(
                toolId: 'summarize',
                onTap: () {},
                showDescription: true,
              ),
            ],
          ),
          locale: const Locale('de'),
        ),
      );
      expect(tester.getSize(find.byType(DkToolRow).first).height, 56);
      expect(find.text('PDF zusammenfügen'), findsOneWidget);
      expect(find.byType(DkProBadge), findsOneWidget, reason: 'Summarize');
      expect(find.textContaining('zusammenfassen'), findsOneWidget);
      await tester.tap(find.byType(DkToolRow).first);
      expect(taps, 1);
    });
  });
}
