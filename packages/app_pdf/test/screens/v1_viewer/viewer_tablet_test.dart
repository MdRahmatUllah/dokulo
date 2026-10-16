import 'package:app_pdf/components/dk_bottom_bars.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/screens/v1_viewer/viewer_screen.dart';
import 'package:app_pdf/screens/v1_viewer/viewer_tablet.dart';
import 'package:app_pdf/screens/v1_viewer/viewer_thumb_strip.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import '../viewer_screen_test.dart' show app, fixture, settle;

// V1 on a tablet (DK-0310; UI spec §17.4, 24-tablet/tablet-viewer-*).
void main() {
  setUpAll(pdfrxInitialize);

  Future<void> pump(WidgetTester tester, Size size, {DkTokens? tokens}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = DokuloDatabase.memory();
    addTearDown(db.close);
    final id = (await tester.runAsync(
      () => db
          .into(db.files)
          .insert(
            FilesCompanion.insert(
              path: fixture('Mietvertrag Musterstraße 12.pdf'),
              name: 'Mietvertrag Musterstraße 12.pdf',
              size: 1,
              created: DateTime(2026),
              modified: DateTime(2026),
            ),
          ),
    ))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: app(
          Scaffold(body: ViewerScreen(fileId: id)),
          tokens: tokens,
        ),
      ),
    );
    await settle(tester);
  }

  Finder sidebar() => find.byWidgetPredicate(
    (w) => w is ViewerThumbStrip && w.axis == Axis.vertical,
  );

  testWidgets('landscape: the actions in the top bar, no bottom bar, the '
      'thumbnails down the side; the toggle hides and shows them', (
    tester,
  ) async {
    await pump(tester, const Size(1366, 1024));
    expect(find.byType(ViewerTabletChrome), findsOneWidget);
    expect(find.byType(DkViewerBar), findsNothing);
    for (final label in ['Edit', 'Sign', 'AI', 'Tools']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(sidebar(), findsOneWidget);
    expect(tester.getSize(sidebar()).width, ViewerThumbStrip.sidebarWidth);

    await tester.tap(find.byTooltip('Thumbnails'));
    await settle(tester, rounds: 10);
    expect(sidebar(), findsNothing);
    await tester.tap(find.byTooltip('Thumbnails'));
    await settle(tester, rounds: 10);
    expect(sidebar(), findsOneWidget);
  });

  testWidgets('portrait: the sidebar starts hidden', (tester) async {
    await pump(tester, const Size(1024, 1366));
    expect(find.byType(ViewerTabletChrome), findsOneWidget);
    expect(sidebar(), findsNothing);
  });

  testWidgets('a phone keeps the phone chrome', (tester) async {
    await pump(tester, const Size(393, 852));
    expect(find.byType(ViewerTabletChrome), findsNothing);
    expect(find.byType(DkViewerBar), findsOneWidget);
  });

  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('golden: tablet-viewer-landscape, $name', (tester) async {
      await pump(tester, const Size(1366, 1024), tokens: tokens);
      await settle(tester, rounds: 20);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/viewer_tablet_landscape_$name.png'),
      );
    });

    // The frame's portrait size (§32.3): the sidebar starts hidden (DK-0966).
    testWidgets('golden: tablet-viewer-portrait, $name', (tester) async {
      await pump(tester, const Size(820, 1180), tokens: tokens);
      await settle(tester, rounds: 20);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/viewer_tablet_portrait_$name.png'),
      );
    });
  }
}
