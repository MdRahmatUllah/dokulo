import 'package:app_pdf/components/dk_bottom_bars.dart';
import 'package:app_pdf/components/dk_text_rules.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/screens/v1_viewer/viewer_chrome.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late VoidCallback tap, scrolled;
  late List<String> calls;

  Future<void> pump(
    WidgetTester tester, {
    DkTokens? tokens,
    Locale locale = const Locale('en'),
    bool screenReader = false,
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (screenReader) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }
    calls = [];
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dokuloTheme(tokens ?? DkTokens.light),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ViewerChrome(
            name: 'Mietvertrag Musterstraße 12.pdf',
            page: 1,
            pageCount: 12,
            actions: ViewerActions(
              onSign: () => calls.add('sign'),
              onAi: () => calls.add('ai'),
              onShare: () => calls.add('share'),
              onSearch: () => calls.add('search'),
            ),
            canvas: (onTap, onScrollStart) {
              tap = onTap;
              scrolled = onScrollStart;
              return const ColoredBox(color: Color(0xFFF2F0EA));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool barVisible(WidgetTester tester) =>
      tester.widget<DkViewerBar>(find.byType(DkViewerBar)).visible;

  testWidgets('the bars, the page pill and the actions', (tester) async {
    await pump(tester);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is DkMiddleEllipsisText &&
            w.name == 'Mietvertrag Musterstraße 12.pdf',
      ),
      findsOneWidget,
    );
    expect(find.text('1 / 12'), findsOneWidget);
    await tester.tap(find.text('Sign'));
    await tester.tap(find.text('AI'));
    await tester.tap(find.text('Share'));
    expect(calls, ['sign', 'ai', 'share']);
  });

  testWidgets('a tap hides the bars and the next shows them; the pill stays', (
    tester,
  ) async {
    await pump(tester);
    tap();
    await tester.pumpAndSettle();
    expect(barVisible(tester), isFalse);
    expect(find.text('1 / 12'), findsOneWidget);
    tap();
    await tester.pumpAndSettle();
    expect(barVisible(tester), isTrue);
  });

  testWidgets('scrolling hides them after 3 s', (tester) async {
    await pump(tester);
    scrolled();
    await tester.pump(const Duration(seconds: 2));
    expect(barVisible(tester), isTrue);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(barVisible(tester), isFalse);
  });

  testWidgets('never hidden with a screen reader on', (tester) async {
    await pump(tester, screenReader: true);
    tap();
    scrolled();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(barVisible(tester), isTrue);
  });

  for (final (name, tokens, locale) in [
    ('light', DkTokens.light, const Locale('en')),
    ('dark', DkTokens.dark, const Locale('en')),
    ('de', DkTokens.light, const Locale('de')),
  ]) {
    testWidgets('golden: viewer chrome ($name)', (tester) async {
      await pump(tester, tokens: tokens, locale: locale);
      await expectLater(
        find.byType(ViewerChrome),
        matchesGoldenFile('goldens/viewer_chrome_$name.png'),
      );
    });
  }
}
