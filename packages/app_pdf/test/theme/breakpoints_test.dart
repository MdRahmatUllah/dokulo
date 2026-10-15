import 'package:app_pdf/components/dk_tab_bar.dart';
import 'package:app_pdf/components/dk_tool_tile.dart';
import 'package:app_pdf/theme/dk_layout.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/home_screen_test.dart' show pumpHome;

/// The breakpoints (DK-0657; UI spec §10): compact < 600, medium 600-839,
/// expanded from 840, on the frames the spec names.
void main() {
  test('the classes change at 600 and 840', () {
    expect(DkGrid.forWidth(599), DkGrid.phone);
    expect(DkGrid.forWidth(600), DkGrid.smallTablet);
    expect(DkGrid.forWidth(839), DkGrid.smallTablet);
    expect(DkGrid.forWidth(840), DkGrid.largeTablet);
  });

  late DokuloDatabase db;
  setUp(() => db = DokuloDatabase.memory());
  tearDown(() => db.close());

  /// How many tools share the first row's top.
  int toolsAcross(WidgetTester tester) {
    final tops = [
      for (final e in find.byType(DkToolTile).evaluate())
        tester.getTopLeft(find.byWidget(e.widget)).dy,
    ];
    return tops.where((y) => y == tops.first).length;
  }

  for (final (size, across, rail) in [
    (const Size(393, 852), 4, false),
    (const Size(375, 667), 4, false),
    (const Size(412, 915), 4, false),
    (const Size(820, 1180), 6, false),
    (const Size(1366, 1024), 8, true),
  ]) {
    testWidgets('H1 at ${size.width.toInt()} × ${size.height.toInt()}: '
        '$across tools across, ${rail ? 'rail' : 'tab bar'}', (tester) async {
      await pumpHome(tester, db, size: size);
      expect(tester.takeException(), isNull); // no overflow
      expect(toolsAcross(tester), across);
      expect(find.byType(DkNavRail), rail ? findsOneWidget : findsNothing);
      expect(find.byType(DkTabBar), rail ? findsNothing : findsOneWidget);
    });
  }

  testWidgets('a phone at 160 % text: 2 tools across', (tester) async {
    await pumpHome(tester, db, textScale: 1.6);
    expect(toolsAcross(tester), 2);
  });
}
