import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/patterns/dk_outline_sheet.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  int? chosen;

  Future<void> open(WidgetTester tester, List<OutlineEntry> outline) async {
    chosen = null;
    await tester.pumpWidget(
      MaterialApp(
        theme: dokuloTheme(DkTokens.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                chosen = await showOutlineSheet(context, outline),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('nested entries with their pages; a tap answers the page', (
    tester,
  ) async {
    await open(tester, const [
      OutlineEntry(title: 'Intro', page: 0),
      OutlineEntry(
        title: 'Terms',
        page: 1,
        children: [OutlineEntry(title: '§ 3 Rent', page: 6)],
      ),
      OutlineEntry(title: 'Elsewhere', page: null),
    ]);
    expect(find.text('Contents'), findsOneWidget);
    expect(find.text('7'), findsOneWidget, reason: 'page 7, 1-based');
    expect(
      tester.getTopLeft(find.text('§ 3 Rent')).dx,
      greaterThan(tester.getTopLeft(find.text('Terms')).dx),
      reason: 'indented',
    );
    // An entry pointing nowhere can't be tapped.
    await tester.tap(find.text('Elsewhere'));
    await tester.pumpAndSettle();
    expect(find.text('Contents'), findsOneWidget);
    await tester.tap(find.text('§ 3 Rent'));
    await tester.pumpAndSettle();
    expect(find.text('Contents'), findsNothing);
    expect(chosen, 6);
  });

  testWidgets('no outline: it says so', (tester) async {
    await open(tester, const []);
    expect(find.text('This PDF has no table of contents.'), findsOneWidget);
  });
}
