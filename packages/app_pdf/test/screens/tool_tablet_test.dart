import 'dart:io';

import 'package:app_pdf/components/dk_action_bar.dart';
import 'package:app_pdf/components/dk_pdf_canvas.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/providers/database_providers.dart';
import 'package:app_pdf/screens/t2_tool/tool_layout.dart';
import 'package:app_pdf/screens/t2_tool/tool_options_providers.dart';
import 'package:app_pdf/screens/t2_tool/tool_options_screen.dart';
import 'package:app_pdf/screens/t3_result/tool_result_screen.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:app_pdf/tools/tool_definition.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

String fixture(String name) =>
    '${Directory.current.path}/../../test/fixtures/$name';

/// T2 and T3 on tablets (DK-0388).
void main() {
  setUpAll(pdfrxInitialize);
  late DokuloDatabase db;
  late int id;

  setUp(() => db = DokuloDatabase.memory());
  tearDown(() => db.close());

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget screen,
    Size size,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    id = (await tester.runAsync(
      () => db
          .into(db.files)
          .insert(
            FilesCompanion.insert(
              path: fixture('Invoice INV-2026-014.pdf'),
              name: 'Invoice INV-2026-014.pdf',
              size: 1000,
              created: DateTime(2026),
              modified: DateTime(2026),
            ),
          ),
    ))!;
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dokuloTheme(DkTokens.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: screen,
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    return container;
  }

  const def = ToolDefinition(id: 'compress');

  testWidgets('T2, large tablet: the options and the button in a 480 '
      'column, the live preview beside them', (tester) async {
    await pump(
      tester,
      Builder(
        builder: (_) => ToolOptionsScreen(definition: def, fileIds: [id]),
      ),
      const Size(1366, 1024),
    );
    expect(find.text('Live preview'), findsOneWidget);
    expect(find.byType(DkPdfCanvas), findsOneWidget);
    expect(find.text('Processed on this tablet'), findsOneWidget);
    expect(
      tester.getSize(find.byType(DkActionBar)).width,
      ToolLayout.columnWidth,
      reason: 'in the column, not across the screen',
    );
  });

  testWidgets('T2, small tablet: one 640-wide column, no preview pane', (
    tester,
  ) async {
    await pump(
      tester,
      ToolOptionsScreen(definition: def, fileIds: [id]),
      const Size(820, 1180),
    );
    expect(find.text('Live preview'), findsNothing);
    expect(tester.getSize(find.byType(DkActionBar)).width, ToolLayout.maxWidth);
    expect(
      tester.getSize(find.byType(ListView).first).width,
      ToolLayout.maxWidth,
    );
  });

  testWidgets("T3, large tablet: the result's preview beside it", (
    tester,
  ) async {
    final out =
        File('${Directory.systemTemp.createTempSync('dk_tab_').path}/out.pdf')
          ..writeAsBytesSync(
            File(fixture('Invoice INV-2026-014.pdf')).readAsBytesSync(),
          );
    final container = await pump(
      tester,
      const SizedBox(),
      const Size(1366, 1024),
    );
    container
        .read(lastToolResultProvider.notifier)
        .set(
          ToolResult(
            toolId: 'compress',
            inputs: const [],
            output: OneFile(out.path),
            took: Duration.zero,
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dokuloTheme(DkTokens.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ToolResultScreen(toolId: 'compress'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Result preview'), findsOneWidget);
    expect(find.byType(DkPdfCanvas), findsOneWidget);
  });
}
