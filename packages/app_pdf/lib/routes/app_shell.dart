import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../components/dk_icon.dart';
import '../components/dk_scan_button.dart';
import '../components/dk_tab_bar.dart';
import '../l10n/app_localizations.dart';
import '../patterns/dk_selection.dart';
import '../theme/dk_layout.dart';
import 'bottom_chrome.dart';
import 'routes.dart';

/// Home, Tools, Files and Me, in the user's language.
List<DkTabItem> shellTabs(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return [
    DkTabItem(icon: DkIcons.home, label: l10n.shell_tab_home),
    DkTabItem(icon: DkIcons.toolsTab, label: l10n.shell_tab_tools),
    DkTabItem(icon: DkIcons.files, label: l10n.shell_tab_files),
    DkTabItem(icon: DkIcons.me, label: l10n.shell_tab_me),
  ];
}

/// The four tabs and Scan (UI spec §13.1): DkTabBar with the raised
/// DkScanButton on phones and small tablets, DkNavRail from 840 dp.
///
/// A tab's screen can take the bottom over (selection mode, [DkShellChrome]):
/// the tab bar and Scan step aside meanwhile.
class AppShell extends StatefulWidget {
  const AppShell(this.shell, {super.key});

  final StatefulNavigationShell shell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _tabBarHidden = ValueNotifier(false);

  @override
  void dispose() {
    _tabBarHidden.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DkShellChrome(
    tabBarHidden: _tabBarHidden,
    child: ValueListenableBuilder(
      valueListenable: _tabBarHidden,
      builder: (context, hidden, _) => _frame(context, hidden: hidden),
    ),
  );

  Widget _frame(BuildContext context, {required bool hidden}) {
    final shell = widget.shell;
    final items = shellTabs(context);
    // Tapping the current tab again returns it to its root.
    void select(int i) =>
        shell.goBranch(i, initialLocation: i == shell.currentIndex);
    void scan() => context.push(Routes.scan);

    if (DkGrid.forWidth(MediaQuery.sizeOf(context).width) ==
        DkGrid.largeTablet) {
      return Scaffold(
        bottomNavigationBar: const DkBottomChrome(),
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
    if (hidden) {
      return Scaffold(body: shell, bottomNavigationBar: const DkBottomChrome());
    }
    return Scaffold(
      body: shell,
      floatingActionButton: DkScanButton(
        // DkTabBar shows "Scan" in its gap, in line with the other labels.
        showLabel: false,
        onPressed: scan,
        // Each mode opens S1 in it; Import photos goes to S2's picker
        // (UI spec §13.1, DK-0230).
        onMode: (mode) => context.push(
          mode == DkScanMode.importPhotos
              ? Routes.scanImport
              : Routes.scanIn(mode),
        ),
      ),
      floatingActionButtonLocation: DkTabBar.scanLocation,
      // The running jobs ride above the tab bar, clear of the raised Scan
      // button (DK-0233).
      bottomNavigationBar: DkBottomChrome(
        clearance:
            DkScanButton.diameter / 2 + DkScanButton.ring + DkTabBar.scanRise,
        child: DkTabBar(
          items: items,
          currentIndex: shell.currentIndex,
          onSelect: select,
        ),
      ),
    );
  }
}
