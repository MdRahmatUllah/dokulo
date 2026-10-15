import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../routes/routes_test.dart' show pumpAt;

/// Whole screens against the platform guidelines (DK-0641 touch targets,
/// DK-0640 text at 200 %,
/// DK-0646 contrast; UI spec §28): every target 48 dp, text at
/// 4.5:1 (3:1 large), in light and dark. Labels: test/a11y/screen_reader_test
/// (DK-0637). The catalogue test checks each
/// component alone; this checks them as the screens put them together.
void main() {
  const screens = [
    Routes.home,
    Routes.files,
    Routes.trash,
    Routes.tools,
    Routes.me,
    Routes.models,
    '/me/settings/files',
    '/me/settings/security',
  ];
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    for (final location in screens) {
      testWidgets('$location, $theme', (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final handle = tester.ensureSemantics();
        await pumpAt(tester, location, tokens: tokens);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  }

  // DK-0640: at 200 % text nothing overflows (an overflow is an exception
  // in a test), on the smallest phone frame.
  for (final location in screens) {
    testWidgets('$location at 200 % text', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpAt(tester, location);
      expect(tester.takeException(), isNull);
    });
  }
}
