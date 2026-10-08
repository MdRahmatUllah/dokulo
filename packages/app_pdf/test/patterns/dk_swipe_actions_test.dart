import 'package:app_pdf/components/dk_file_card.dart';
import 'package:app_pdf/patterns/dk_swipe_actions.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

final done = <String>[];

Widget app({bool reduce = false, Locale locale = const Locale('en')}) =>
    MaterialApp(
      theme: dokuloTheme(DkTokens.light),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
        child: child!,
      ),
      home: Scaffold(
        body: Column(
          children: [
            DkSwipeActions(
              onShare: () => done.add('share'),
              onDelete: () => done.add('delete'),
              // The real row: the actions go on DkFileCard's own node.
              builder: (context, actions) => DkFileCard(
                name: 'Invoice.pdf',
                meta: '2 pages',
                thumbnail: const SizedBox(),
                onTap: () {},
                semanticsActions: actions,
              ),
            ),
          ],
        ),
      ),
    );

/// How far the row has moved left.
double moved(WidgetTester tester) => -tester
    .widget<Transform>(
      // The swipe's own translate, not the card's press transform inside.
      find
          .descendant(
            of: find.byType(DkSwipeActions),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .getTranslation()
    .x;

void main() {
  setUp(done.clear);

  testWidgets('past half an action it stays open on Share and Delete, 80 '
      'each; Delete runs and closes', (tester) async {
    await tester.pumpWidget(app());
    await tester.drag(find.text('Invoice.pdf'), const Offset(-60, 0));
    await tester.pumpAndSettle();
    expect(moved(tester), 160);
    expect(tester.getSize(find.widgetWithText(InkWell, 'Share')).width, 80);
    expect(tester.getSize(find.widgetWithText(InkWell, 'Delete')).width, 80);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(done, ['delete']);
    expect(moved(tester), 0);
  });

  testWidgets('a short swipe closes again', (tester) async {
    await tester.pumpWidget(app());
    await tester.drag(find.text('Invoice.pdf'), const Offset(-30, 0));
    await tester.pumpAndSettle();
    expect(moved(tester), 0);
    expect(find.text('Share'), findsNothing);
  });

  testWidgets('a full swipe deletes', (tester) async {
    await tester.pumpWidget(app());
    await tester.drag(find.text('Invoice.pdf'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(done, ['delete']);
  });

  testWidgets('with Reduce Motion it snaps without animating', (tester) async {
    await tester.pumpWidget(app(reduce: true));
    await tester.drag(find.text('Invoice.pdf'), const Offset(-60, 0));
    await tester.pump();
    expect(moved(tester), 160);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('screen readers: Share and Delete as actions, EN and DE', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    for (final (locale, share, delete) in [
      (const Locale('en'), 'Share', 'Delete'),
      (const Locale('de'), 'Teilen', 'Löschen'),
    ]) {
      done.clear();
      await tester.pumpWidget(app(locale: locale));
      // On the card's node, the one screen readers focus.
      final node = tester.getSemantics(find.text('Invoice.pdf'));
      final owner = tester.binding.renderViews.first.owner!.semanticsOwner!;
      for (final label in [share, delete]) {
        final action = node
            .getSemanticsData()
            .customSemanticsActionIds!
            .map(CustomSemanticsAction.getAction)
            .firstWhere((a) => a!.label == label)!;
        owner.performAction(
          node.id,
          SemanticsAction.customAction,
          CustomSemanticsAction.getIdentifier(action),
        );
      }
      expect(done, ['share', 'delete'], reason: locale.languageCode);
    }
    handle.dispose();
  });
}
