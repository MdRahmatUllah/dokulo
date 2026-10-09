import 'package:ai_core/ai_core.dart';
import 'package:app_pdf/components/dk_chip.dart';
import 'package:app_pdf/components/dk_tool_tile.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/device_providers.dart';
import 'package:app_pdf/routes/routes.dart';
import 'package:app_pdf/screens/t1_tools/tools_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:app_pdf/tools/tool_catalogue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _gib = 1 << 30;

Future<GoRouter> pumpTools(
  WidgetTester tester, {
  AiEligibility ai = AiEligibility.eligible,
  int ram = 8 * _gib,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: Routes.tools,
    routes: [
      GoRoute(path: Routes.tools, builder: (_, _) => const ToolsScreen()),
      GoRoute(
        path: '/tool/:id',
        builder: (_, s) => Text('T2 ${s.pathParameters['id']}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gemmaEligibilityProvider.overrideWith((ref) async => ai),
        deviceCapabilitiesProvider.overrideWith(
          (ref) async => DeviceCapabilities(totalRam: ram),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: dokuloTheme(DkTokens.light),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

DkChip chip(WidgetTester tester, String label) => tester.widget<DkChip>(
  find.ancestor(of: find.text(label), matching: find.byType(DkChip)),
);

void main() {
  testWidgets('sections in the spec order, each with its count', (
    tester,
  ) async {
    await pumpTools(tester);
    expect(find.text('Organize'), findsNWidgets(2)); // the chip and header
    expect(find.text('6 tools'), findsOneWidget);
    expect(find.text('Search tools'), findsOneWidget);
    // The first section's tiles, in order (the rest are off screen).
    final ids = [
      for (final t in tester.widgetList<DkToolTile>(find.byType(DkToolTile)))
        t.toolId,
    ];
    expect(ids.take(6), [
      'merge',
      'split',
      'extract',
      'organize',
      'rotate',
      'smartsplit',
    ]);
    expect(chip(tester, 'All').selected, isTrue);
  });

  testWidgets('a chip scrolls to its section and stays selected', (
    tester,
  ) async {
    await pumpTools(tester);
    await tester.ensureVisible(find.text('Security').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Security').first);
    await tester.pumpAndSettle();
    expect(chip(tester, 'Security').selected, isTrue);
    expect(find.text('Sign PDF'), findsOneWidget);
    await tester.ensureVisible(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(chip(tester, 'All').selected, isTrue);
    expect(find.text('Merge PDF'), findsOneWidget);
  });

  testWidgets('the selection follows the scroll', (tester) async {
    await pumpTools(tester);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    final selected = [
      for (final c in tester.widgetList<DkChip>(find.byType(DkChip)))
        if (c.selected) c.label,
    ];
    expect(selected, hasLength(1));
    expect(selected.single, isNot('All'));
    // At the very end, the last section.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(chip(tester, 'Automation').selected, isTrue);
  });

  testWidgets('a tile opens T2', (tester) async {
    await pumpTools(tester);
    await tester.tap(find.text('Merge PDF'));
    await tester.pumpAndSettle();
    expect(find.text('T2 merge'), findsOneWidget);
  });

  testWidgets('too little memory: an AI tile explains instead of opening', (
    tester,
  ) async {
    await pumpTools(
      tester,
      ai: AiEligibility.tooLittleRam,
      ram: (3.6 * _gib).round(),
    );
    await tester.ensureVisible(find.text('AI').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Summarize'));
    await tester.pumpAndSettle();
    expect(find.text("AI isn't available on this phone"), findsOneWidget);
    expect(
      find.text('It needs at least 6 GB of memory. This phone has 4 GB.'),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text("AI isn't available on this phone"), findsNothing);
  });

  testWidgets('a 32-bit phone has no AI section', (tester) async {
    await pumpTools(tester, ai: AiEligibility.notArm64);
    expect(find.text('AI'), findsNothing);
    expect(
      ToolCatalogue.inCategory(ToolCategory.ai).map((t) => t.id),
      contains('summarize'),
    );
  });

  testWidgets('German', (tester) async {
    await pumpTools(tester, locale: const Locale('de'));
    expect(find.text('Werkzeuge suchen'), findsOneWidget);
    expect(find.text('Alle'), findsOneWidget);
    expect(find.text('6 Werkzeuge'), findsOneWidget);
  });
}
