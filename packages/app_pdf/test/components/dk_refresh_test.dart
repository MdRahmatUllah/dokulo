import 'package:app_pdf/components/dk_refresh.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(
  Future<void> Function() onRefresh, {
  TargetPlatform platform = TargetPlatform.android,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dokuloTheme(DkTokens.light).copyWith(platform: platform),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: DkRefresh(
      onRefresh: onRefresh,
      child: ListView(children: [for (var i = 0; i < 30; i++) Text('File $i')]),
    ),
  ),
);

void main() {
  for (final (platform, spinner) in [
    (TargetPlatform.android, RefreshProgressIndicator),
    (TargetPlatform.iOS, CupertinoActivityIndicator),
  ]) {
    testWidgets('pulling down refreshes under the platform spinner: '
        '${platform.name}', (tester) async {
      var refreshed = 0;
      await tester.pumpWidget(
        app(() async {
          refreshed++;
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }, platform: platform),
      );
      await tester.fling(find.text('File 0'), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(spinner), findsOne);
      await tester.pumpAndSettle();
      expect(refreshed, 1);
    });
  }

  testWidgets('screen readers: a Refresh action, in EN and DE', (tester) async {
    final handle = tester.ensureSemantics();
    for (final (locale, label) in [
      (const Locale('en'), 'Refresh'),
      (const Locale('de'), 'Aktualisieren'),
    ]) {
      var refreshed = 0;
      await tester.pumpWidget(app(() async => refreshed++, locale: locale));
      final owner = tester.binding.renderViews.first.owner!.semanticsOwner!;
      final node = tester.getSemantics(find.byType(DkRefresh));
      final id = node
          .getSemanticsData()
          .customSemanticsActionIds!
          .map(CustomSemanticsAction.getAction)
          .firstWhere((a) => a!.label == label);
      owner.performAction(
        node.id,
        SemanticsAction.customAction,
        CustomSemanticsAction.getIdentifier(id!),
      );
      await tester.pump();
      expect(refreshed, 1, reason: label);
    }
    handle.dispose();
  });
}
