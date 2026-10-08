import 'package:app_pdf/catalogue/folder_settings_states.dart';
import 'package:app_pdf/components/dk_folder_card.dart';
import 'package:app_pdf/components/dk_ring.dart';
import 'package:app_pdf/components/dk_settings_row.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_folder_tags.dart';
import 'package:app_pdf/theme/dk_layout.dart';
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

void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final (lang, scale) in [('en', 1.0), ('en', 2.0), ('de', 2.0)]) {
      final name = '${theme}_${lang}_${(scale * 100).round()}';
      testWidgets('golden: $name', (tester) async {
        tester.view.physicalSize = Size(393, scale > 1 ? 1500 : 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(
            const SingleChildScrollView(child: DkFolderSettingsGallery()),
            tokens: tokens,
            scale: scale,
            locale: Locale(lang),
          ),
        );
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/folder_settings_$name.png'),
        );
      });
    }
  }

  group('DkFolderCard (DK-0088)', () {
    testWidgets('a 64 dp row: the tag colour, "8 files", one node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        app(
          DkFolderCard(
            name: 'Taxes',
            files: 8,
            tag: DkFolderTag.green,
            onTap: () => taps++,
          ),
          locale: const Locale('de'),
        ),
      );
      expect(tester.getSize(find.byType(DkFolderCard)).height, 64);
      expect(
        tester.widget<Icon>(find.byType(Icon)).color,
        DkFolderTag.green.colour,
      );
      expect(find.text('8 Dateien'), findsOneWidget);
      expect(find.bySemanticsLabel('Taxes\n8 Dateien'), findsOneWidget);
      await tester.tap(find.byType(DkFolderCard));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('untagged: iconSecondary; a drop target has the 2 dp ring', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          DkFolderCard(name: 'Work', files: 1, onTap: () {}, dropTarget: true),
        ),
      );
      expect(
        tester.widget<Icon>(find.byType(Icon)).color,
        DkTokens.light.color.iconSecondary,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is DkRing && w.side == DkTokens.light.selectionRing,
        ),
        findsOneWidget,
      );
    });
  });

  group('DkSettingsRow (DK-0100)', () {
    testWidgets('56 dp, 72 with a description; value and chevron; one node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        app(
          DkSettingsGroup(
            title: 'Appearance',
            children: [
              DkSettingsRow(
                title: 'Theme',
                value: 'System',
                onTap: () => taps++,
              ),
              const DkSettingsRow(title: 'Haptics', description: 'A light tap'),
            ],
          ),
        ),
      );
      expect(tester.getSize(find.byType(DkSettingsRow).first).height, 56);
      expect(tester.getSize(find.byType(DkSettingsRow).last).height, 72);
      expect(find.text('System'), findsOneWidget);
      await tester.tap(find.text('Theme'));
      expect(taps, 1);
      expect(
        find.bySemanticsLabel(RegExp(r'^Theme\nSystem$')),
        findsOneWidget,
        reason: 'the title and the value in one node',
      );
      expect(find.bySemanticsLabel('Appearance'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a long value at 200 % leaves room for the title', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          DkSettingsRow(
            title: 'Language',
            value: 'Deutsch (Deutschland)',
            onTap: () {},
          ),
          scale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.text('Language')).width, greaterThan(40));
    });

    testWidgets('a switch row reads as the switch with its title', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        app(
          DkSettingsRow(
            title: 'Haptics',
            trailing: Switch(value: true, onChanged: (_) {}),
          ),
        ),
      );
      final node = tester.getSemantics(find.byType(Switch));
      expect(node.label, contains('Haptics'));
      handle.dispose();
    });
  });
}
