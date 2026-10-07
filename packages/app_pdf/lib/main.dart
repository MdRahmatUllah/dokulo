import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'providers/job_providers.dart';
import 'providers/language_providers.dart';
import 'providers/theme_providers.dart';
import 'routes/routes.dart';

void main() => runApp(const ProviderScope(child: DokuloApp()));

/// The app root: the router (DK-0004) and the theme mode. The theme itself
/// arrives with DK-0024.
class DokuloApp extends ConsumerWidget {
  const DokuloApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Starts the launch cleanup and job recovery once (DK-0021); Home reads
    // its report.
    ref.listen(startupProvider, (_, _) {});
    return MaterialApp.router(
      title:
          'Dokulo', // l10n-ignore: the brand name, the same in every language
      themeMode: ref.watch(appThemeModeProvider),
      theme: ThemeData(brightness: Brightness.light),
      darkTheme: ThemeData(brightness: Brightness.dark),
      locale: ref.watch(appLanguageSettingProvider).locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
