import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import 'l10n/app_localizations.dart';
import 'patterns/dk_app_lock.dart';
import 'patterns/dk_incoming_files.dart';
import 'patterns/dk_privacy_cover.dart';
import 'providers/crash_providers.dart';
import 'providers/job_providers.dart';
import 'providers/language_providers.dart';
import 'providers/theme_providers.dart';
import 'routes/routes.dart';
import 'theme/app_theme.dart';
import 'theme/dk_tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  installCrashHooks(container); // opt-in, local only (DK-0011)
  // PDFium (pdfrx) for the viewer and doc_core's PDF engine (DK-0293).
  // ponytail: awaited before runApp; move it off the cold-start path if the
  // launch budget (DK-1067) says so.
  await pdfrxFlutterInitialize();
  runApp(
    UncontrolledProviderScope(container: container, child: const DokuloApp()),
  );
}

/// The app root: the router (DK-0004), the theme mode and the design tokens
/// (DK-0024).
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
      theme: dokuloTheme(DkTokens.light),
      darkTheme: dokuloTheme(DkTokens.dark),
      locale: ref.watch(appLanguageSettingProvider).locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(appRouterProvider),
      // The app switcher's privacy cover over everything (DK-0234), and
      // under it the app lock (DK-0290); files shared to Dokulo open X1 or
      // V1 (DK-0235).
      builder: (context, child) => DkPrivacyCover(
        child: DkAppLock(child: DkIncomingFiles(child: child!)),
      ),
    );
  }
}
