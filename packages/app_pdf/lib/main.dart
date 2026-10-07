import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_language.dart';
import 'l10n/app_localizations.dart';

void main() => runApp(DokuloApp());

/// The app root. The shell, routes and theme arrive with DK-0004 and DK-0024.
class DokuloApp extends StatelessWidget {
  DokuloApp({super.key, AppLanguageController? language})
    : language = language ?? AppLanguageController();

  final AppLanguageController language;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: language,
    builder: (context, choice, _) => MaterialApp(
      title:
          'Dokulo', // l10n-ignore: the brand name, the same in every language
      locale: choice.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _Placeholder(),
    ),
  );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Text(AppLocalizations.of(context).privacy_line_home)),
  );
}
