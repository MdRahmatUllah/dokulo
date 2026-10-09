import 'package:app_pdf/main.dart';
import 'package:app_pdf/providers/theme_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_overrides.dart';

ThemeMode appMode(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

void main() {
  testWidgets('the app follows the theme-mode provider', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: homeOverrides(), child: const DokuloApp()),
    );
    expect(appMode(tester), ThemeMode.system);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DokuloApp)),
    );
    container.read(appThemeModeProvider.notifier).select(ThemeMode.dark);
    await tester.pump();
    expect(appMode(tester), ThemeMode.dark);
  });

  testWidgets('tests override providers through ProviderScope', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appThemeModeProvider.overrideWithBuild((ref, _) => ThemeMode.light),
          ...homeOverrides(),
        ],
        child: const DokuloApp(),
      ),
    );
    expect(appMode(tester), ThemeMode.light);
  });
}
