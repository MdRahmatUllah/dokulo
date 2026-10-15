import 'package:app_pdf/components/dk_icon.dart';
import 'package:app_pdf/components/dk_loading_spinner.dart';
import 'package:app_pdf/components/dk_settings_row.dart';
import 'package:app_pdf/components/dk_switch.dart';
import 'package:app_pdf/components/dk_top_bar.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One screen with every shell difference of UI spec §13.2 (DK-0231): the
/// back and overflow icons, the title alignment, share, the switch, the
/// biometric icon and the spinner.
Widget screen(TargetPlatform platform) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(DkTokens.light).copyWith(platform: platform),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) => Scaffold(
      backgroundColor: context.tokens.color.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(DkTopBar.height),
        child: DkTopBar(
          title: 'Security',
          onLeading: () {},
          actions: [
            DkTopBarAction(
              icon: DkIcons.share(context),
              tooltip: 'Share',
              onPressed: () {},
            ),
          ],
          onOverflow: (_) {},
        ),
      ),
      body: Column(
        children: [
          DkSettingsGroup(
            title: 'App lock',
            children: [
              DkSettingsRow(
                icon: DkIcons.biometrics(context, faceId: true),
                title: 'Unlock with Face ID',
                trailing: DkSwitch(value: true, onChanged: (_) {}),
              ),
              DkSettingsRow(
                title: 'Hide previews',
                trailing: DkSwitch(value: false, onChanged: (_) {}),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const DkLoadingSpinner(size: DkSpinnerSize.large),
        ],
      ),
    ),
  ),
);

void main() {
  for (final (name, platform) in [
    ('android', TargetPlatform.android),
    ('ios', TargetPlatform.iOS),
  ]) {
    testWidgets('golden: platform_$name, one screen per platform', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true), // still spinner
          child: screen(platform),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/platform_$name.png'),
      );
    });
  }

  testWidgets('no Cupertino on Android, no Material switch or spinner on iOS', (
    tester,
  ) async {
    Set<String> types() => {
      for (final e in find.byWidgetPredicate((_) => true).evaluate())
        e.widget.runtimeType.toString(),
    };

    await tester.pumpWidget(screen(TargetPlatform.android));
    final android = types();
    // Theme puts a CupertinoTheme in every app: it draws nothing.
    expect(
      android.where((t) => t.startsWith('Cupertino') && t != 'CupertinoTheme'),
      isEmpty,
    );
    expect(android, containsAll(['Switch', 'CircularProgressIndicator']));

    await tester.pumpWidget(screen(TargetPlatform.iOS));
    // MaterialApp animates the theme: let it reach iOS.
    await tester.pump(const Duration(seconds: 1));
    final ios = types();
    expect(ios, containsAll(['CupertinoSwitch', 'CupertinoActivityIndicator']));
    expect(ios, isNot(contains('Switch')));
    expect(ios, isNot(contains('CircularProgressIndicator')));
  });

  testWidgets('the icons differ as §13.2 says', (tester) async {
    late BuildContext android, ios;
    await tester.pumpWidget(
      Column(
        children: [
          for (final p in [TargetPlatform.android, TargetPlatform.iOS])
            Theme(
              data: ThemeData(platform: p),
              child: Builder(
                builder: (c) {
                  p == TargetPlatform.iOS ? ios = c : android = c;
                  return const SizedBox();
                },
              ),
            ),
        ],
      ),
    );
    String glyph(IconData i) => i.codePoint.toRadixString(16);
    expect(glyph(DkIcons.back(android)), 'e5c4'); // arrow_back
    expect(glyph(DkIcons.back(ios)), 'e2ea'); // arrow_back_ios_new
    expect(glyph(DkIcons.overflow(android)), 'e5d4'); // more_vert
    expect(glyph(DkIcons.overflow(ios)), 'e5d3'); // more_horiz
    expect(glyph(DkIcons.share(android)), 'e80d'); // share
    expect(glyph(DkIcons.share(ios)), 'e6b8'); // ios_share
    expect(glyph(DkIcons.biometrics(ios, faceId: true)), 'f008'); // face
    expect(glyph(DkIcons.biometrics(ios, faceId: false)), 'e90d');
    expect(glyph(DkIcons.biometrics(android, faceId: true)), 'e90d');
  });
}
