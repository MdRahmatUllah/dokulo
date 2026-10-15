import 'package:app_pdf/components/dk_page_thumb.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/screens/v1_viewer/viewer_thumb_strip.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<int>> pump(WidgetTester tester, {required int current}) async {
    final taps = <int>[];
    tester.view.physicalSize = const Size(393, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: dokuloTheme(DkTokens.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ViewerThumbStrip(
                path: 'missing.pdf', // no render: skeletons with numbers
                pageCount: 40,
                current: current,
                onPage: taps.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return taps;
  }

  Finder thumb(int n) =>
      find.byWidgetPredicate((w) => w is DkPageThumb && w.pageNumber == n);

  testWidgets('the strip (DK-1091): 96 tall, the current page ringed and in '
      'view; a tap answers its page', (tester) async {
    final taps = await pump(tester, current: 18);
    expect(
      tester.getSize(find.byType(ViewerThumbStrip)).height,
      ViewerThumbStrip.height,
    );
    expect(tester.widget<DkPageThumb>(thumb(18)).current, isTrue);
    await tester.tap(thumb(19));
    expect(taps, [19]);
  });

  testWidgets('it follows the current page out of view', (tester) async {
    await pump(tester, current: 1);
    expect(thumb(30), findsNothing);
    await pump(tester, current: 30);
    await tester.pump();
    expect(thumb(30), findsOneWidget);
  });
}
