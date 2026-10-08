import 'package:app_pdf/catalogue/bar_states.dart';
import 'package:app_pdf/components/dk_scan_button.dart';
import 'package:app_pdf/components/dk_tab_bar.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(
  Widget home, {
  DkTokens? tokens,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) => ProviderScope(
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dokuloTheme(tokens ?? DkTokens.light),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery.withClampedTextScaling(
      minScaleFactor: textScale,
      maxScaleFactor: textScale,
      child: home,
    ),
  ),
);

void phone(WidgetTester tester, [Size size = const Size(393, 852)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget bar({int current = 2, ValueChanged<int>? onSelect}) => Scaffold(
  floatingActionButton: DkScanButton(
    showLabel: false,
    onPressed: () {},
    onMode: (_) {},
  ),
  floatingActionButtonLocation: DkTabBar.scanLocation,
  bottomNavigationBar: DkTabBar(
    items: TabBarStates.items,
    currentIndex: current,
    onSelect: onSelect ?? (_) {},
  ),
);

void main() {
  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('tab bar and rail, $name, ${(scale * 100).round()} %', (
        tester,
      ) async {
        phone(tester, const Size(393, 700));
        await tester.pumpWidget(
          app(
            const Scaffold(body: TabBarStates()),
            tokens: tokens,
            textScale: scale,
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(TabBarStates),
          matchesGoldenFile(
            'goldens/tab_bar_${name}_${(scale * 100).round()}.png',
          ),
        );
      });
    }
  }

  testWidgets('64 tall; Scan centred 12 above its top edge, an 88 gap', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(app(bar()));
    await tester.pumpAndSettle();
    final tabBar = tester.getRect(find.byType(DkTabBar));
    expect(tabBar.height, 64);
    final scan = tester.getCenter(find.byType(DkScanButton));
    expect(scan.dx, closeTo(393 / 2, 0.5));
    expect(scan.dy, closeTo(tabBar.top - 12, 0.5));
  });

  testWidgets('selecting a tab; the current one is selected for screen '
      'readers', (tester) async {
    phone(tester);
    final handle = tester.ensureSemantics();
    final picked = <int>[];
    await tester.pumpWidget(app(bar(onSelect: picked.add)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.tap(find.text('Me'));
    expect(picked, [0, 3]);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Files')),
      isSemantics(label: 'Files', isSelected: true, isButton: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Tools')),
      isSemantics(label: 'Tools', isSelected: false, isButton: true),
    );
    handle.dispose();
  });

  testWidgets('the rail: 80 wide, Scan on top, targets of 48', (tester) async {
    phone(tester, const Size(1024, 768));
    var scans = 0;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Row(
            children: [
              DkNavRail(
                items: TabBarStates.items,
                currentIndex: 0,
                onSelect: (_) {},
                onScan: () => scans++,
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(DkNavRail)).width, 80);
    await tester.tap(find.bySemanticsLabel('Scan'));
    expect(scans, 1);
    expect(
      tester
          .getSize(
            find.ancestor(
              of: find.text('Files'),
              matching: find.byType(InkWell),
            ),
          )
          .height,
      greaterThanOrEqualTo(48),
    );
  });
}
