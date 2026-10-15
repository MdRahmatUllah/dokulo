import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/tools_screen_test.dart' show pumpTools;

// Visual QA (DK-0728..DK-0732): the 03-tools frames (default, chip,
// search, searchempty, about), rendered by the real T1 at 393 × 852. The
// goldens sit next to the frames' screenshots in docs/qa/tools/; the
// findings are in docs/qa/tools.md.
void main() {
  for (final (theme, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    Future<void> shot(WidgetTester tester, String frame) => expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/qa_tools_${frame}_$theme.png'),
    );

    testWidgets('tools-default, $theme', (tester) async {
      await pumpTools(tester, tokens: tokens);
      await shot(tester, 'default');
    });

    testWidgets('tools-chip (scrolled, Security), $theme', (tester) async {
      await pumpTools(tester, tokens: tokens);
      await tester.ensureVisible(find.text('Security').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Security').first);
      await tester.pumpAndSettle();
      await shot(tester, 'chip');
    });

    testWidgets('tools-search ("shrink"), $theme', (tester) async {
      await pumpTools(tester, tokens: tokens);
      await tester.enterText(find.byType(EditableText), 'shrink');
      await tester.pumpAndSettle();
      await shot(tester, 'search');
    });

    testWidgets('tools-searchempty ("fax"), $theme', (tester) async {
      await pumpTools(tester, tokens: tokens);
      await tester.enterText(find.byType(EditableText), 'fax');
      await tester.pumpAndSettle();
      await shot(tester, 'searchempty');
    });

    testWidgets('tools-about (Compress PDF), $theme', (tester) async {
      await pumpTools(tester, tokens: tokens);
      await tester.enterText(find.byType(EditableText), 'shrink');
      await tester.pumpAndSettle();
      await tester.tap(find.text('About Compress PDF'));
      await tester.pumpAndSettle();
      await shot(tester, 'about');
    });
  }
}
