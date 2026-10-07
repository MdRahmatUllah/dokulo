import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'providers/language_providers.dart';
import 'providers/theme_providers.dart';

void main() => runApp(const ProviderScope(child: DokuloApp()));

/// The app root. The shell, routes and theme arrive with DK-0004 and DK-0024.
class DokuloApp extends ConsumerWidget {
  const DokuloApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    title: 'Dokulo', // l10n-ignore: the brand name, the same in every language
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
    home: const _Placeholder(),
  );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Text(AppLocalizations.of(context).privacy_line_home)),
  );
}
