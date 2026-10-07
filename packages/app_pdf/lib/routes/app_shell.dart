import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import 'routes.dart';

/// The four tabs plus the raised Scan button (UI spec §13.1). A stand-in for
/// the designed tab bar, which its component task builds.
class AppShell extends StatelessWidget {
  const AppShell(this.shell, {super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: shell,
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.shell_button_scan,
        onPressed: () => context.push(Routes.scan),
        child: const Icon(Icons.document_scanner),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        // Tapping the current tab again returns it to its root.
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home),
            label: l10n.shell_tab_home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.apps),
            label: l10n.shell_tab_tools,
          ),
          NavigationDestination(
            icon: const Icon(Icons.folder),
            label: l10n.shell_tab_files,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person),
            label: l10n.shell_tab_me,
          ),
        ],
      ),
    );
  }
}
