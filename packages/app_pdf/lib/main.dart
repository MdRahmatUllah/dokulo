import 'package:doc_tools/doc_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/theme_providers.dart';

void main() => runApp(const ProviderScope(child: DokuloApp()));

/// The app root. The shell, routes and theme arrive with DK-0004 and DK-0024.
class DokuloApp extends ConsumerWidget {
  const DokuloApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    title: 'Dokulo',
    themeMode: ref.watch(appThemeModeProvider),
    theme: ThemeData(brightness: Brightness.light),
    darkTheme: ThemeData(brightness: Brightness.dark),
    home: const Scaffold(
      body: Center(child: Text('Dokulo · layer $docToolsLayer')),
    ),
  );
}
