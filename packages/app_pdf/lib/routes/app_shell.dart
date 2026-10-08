import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../components/dk_icon.dart';
import '../components/dk_scan_button.dart';
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
      floatingActionButton: DkScanButton(
        // The stand-in bar has no slot for the label; DkTabBar will.
        showLabel: false,
        onPressed: () => context.push(Routes.scan),
        onMode: (mode) => context.push(Routes.scanIn(mode)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        // Tapping the current tab again returns it to its root.
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(
            icon: const DkIcon(DkIcons.home),
            selectedIcon: const DkIcon(DkIcons.home, filled: true),
            label: l10n.shell_tab_home,
          ),
          NavigationDestination(
            icon: const DkIcon(DkIcons.toolsTab),
            selectedIcon: const DkIcon(DkIcons.toolsTab, filled: true),
            label: l10n.shell_tab_tools,
          ),
          NavigationDestination(
            icon: const DkIcon(DkIcons.files),
            selectedIcon: const DkIcon(DkIcons.files, filled: true),
            label: l10n.shell_tab_files,
          ),
          NavigationDestination(
            icon: const DkIcon(DkIcons.me),
            selectedIcon: const DkIcon(DkIcons.me, filled: true),
            label: l10n.shell_tab_me,
          ),
        ],
      ),
    );
  }
}
