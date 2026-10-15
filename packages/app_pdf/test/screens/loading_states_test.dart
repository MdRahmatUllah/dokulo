import 'package:app_pdf/components/dk_loading_spinner.dart';
import 'package:app_pdf/components/dk_page_thumb.dart';
import 'package:app_pdf/components/dk_skeleton.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/screens/v1_viewer/viewer_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget body, {DkTokens? tokens}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(tokens ?? DkTokens.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    backgroundColor: (tokens ?? DkTokens.light).color.surfaceSunken,
    body: body,
  ),
);

/// The loading states of UI spec §26.2 (DK-0620).
void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('golden: viewer_loading_$theme, the page skeleton', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          // Still, so the golden is one frame.
          data: const MediaQueryData(disableAnimations: true),
          child: app(const ViewerPageSkeleton(), tokens: tokens),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/viewer_loading_$theme.png'),
      );
    });
  }

  testWidgets('V1 loading is the page skeleton, one "Loading" for a screen '
      'reader, never a blank screen', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app(const ViewerPageSkeleton()));
    expect(find.byType(DkSkeleton), findsOneWidget);
    expect(find.byType(DkLoadingSpinner), findsOneWidget);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a thumbnail fades in over its skeleton as it renders', (
    tester,
  ) async {
    Widget thumb(Widget? page) => app(
      Center(
        child: SizedBox(
          width: 120,
          child: DkPageThumb(pageNumber: 1, pageCount: 3, page: page),
        ),
      ),
    );
    await tester.pumpWidget(thumb(null));
    const rendered = ColoredBox(
      key: ValueKey('page'),
      color: Color(0xFF00FF00),
      child: SizedBox(width: 30, height: 40),
    );
    await tester.pumpWidget(thumb(rendered));
    await tester.pump(const Duration(milliseconds: 60));
    // Mid-fade: the page is on, partly transparent, over the skeleton.
    final mid = tester
        .widgetList<FadeTransition>(
          find.ancestor(
            of: find.byKey(const ValueKey('page')),
            matching: find.byType(FadeTransition),
          ),
        )
        .first
        .opacity
        .value;
    expect(mid, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget, reason: 'the number stays below');
    expect(find.byKey(const ValueKey('page')), findsOneWidget);
  });
}
