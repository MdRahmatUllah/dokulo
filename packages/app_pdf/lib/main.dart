import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/theme_providers.dart';
import 'routes/routes.dart';

void main() => runApp(const ProviderScope(child: DokuloApp()));

/// The app root: the router (DK-0004) and the theme mode. The theme itself
/// arrives with DK-0024.
class DokuloApp extends ConsumerWidget {
  const DokuloApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Dokulo',
    themeMode: ref.watch(appThemeModeProvider),
    theme: ThemeData(brightness: Brightness.light),
    darkTheme: ThemeData(brightness: Brightness.dark),
    routerConfig: ref.watch(appRouterProvider),
  );
}
