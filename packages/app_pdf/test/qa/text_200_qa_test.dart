import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/home_screen_test.dart' show pumpHome, settle;

// Visual QA (DK-0981): 27-accessibility/text-200-percent, the built panels
// H1 Home and T1 Tools at 200 % text, 393 × 852. T3's is in
// tool_shell_test (result_200_*). The frames' screenshots are in
// docs/qa/accessibility/; the findings are in docs/qa/accessibility.md.
void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    Future<void> shot(WidgetTester tester, String frame) => expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/qa_text200_${frame}_$theme.png'),
    );

    testWidgets('H1 Home at 200 %, $theme', (tester) async {
      final db = DokuloDatabase.memory();
      addTearDown(db.close);
      await pumpHome(tester, db, tokens: tokens, textScale: 2);
      await shot(tester, 'home');
    });

    testWidgets('T1 Tools at 200 %, $theme', (tester) async {
      final db = DokuloDatabase.memory();
      addTearDown(db.close);
      final router = await pumpHome(tester, db, tokens: tokens, textScale: 2);
      router.go(Routes.tools);
      await settle(tester);
      await shot(tester, 'tools');
    });
  }
}
