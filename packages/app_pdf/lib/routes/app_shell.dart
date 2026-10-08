import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../components/dk_icon.dart';
import '../components/dk_scan_button.dart';
import '../components/dk_tab_bar.dart';
import '../l10n/app_localizations.dart';
import '../theme/dk_layout.dart';
import 'routes.dart';

/// The four tabs and Scan (UI spec §13.1): DkTabBar with the raised
/// DkScanButton on phones and small tablets, DkNavRail from 840 dp.
class AppShell extends StatelessWidget {
  const AppShell(this.shell, {super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = [
      DkTabItem(icon: DkIcons.home, label: l10n.shell_tab_home),
      DkTabItem(icon: DkIcons.toolsTab, label: l10n.shell_tab_tools),
      DkTabItem(icon: DkIcons.files, label: l10n.shell_tab_files),
      DkTabItem(icon: DkIcons.me, label: l10n.shell_tab_me),
    ];
    // Tapping the current tab again returns it to its root.
    void select(int i) =>
        shell.goBranch(i, initialLocation: i == shell.currentIndex);
    void scan() => context.push(Routes.scan);

    if (DkGrid.forWidth(MediaQuery.sizeOf(context).width) ==
        DkGrid.largeTablet) {
      return Scaffold(
        body: Row(
          children: [
            DkNavRail(
              items: items,
              currentIndex: shell.currentIndex,
              onSelect: select,
              onScan: scan,
            ),
            Expanded(child: shell),
          ],
        ),
      );
    }
    return Scaffold(
      body: shell,
      floatingActionButton: DkScanButton(
        // DkTabBar shows "Scan" in its gap, in line with the other labels.
        showLabel: false,
        onPressed: scan,
        onMode: (mode) => context.push(Routes.scanIn(mode)),
      ),
      floatingActionButtonLocation: DkTabBar.scanLocation,
      bottomNavigationBar: DkTabBar(
        items: items,
        currentIndex: shell.currentIndex,
        onSelect: select,
      ),
    );
  }
}
