import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';

/// The four tabs plus the raised Scan button (UI spec §13.1). A stand-in for
/// the designed tab bar, which its component task builds.
class AppShell extends StatelessWidget {
  const AppShell(this.shell, {super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    floatingActionButton: FloatingActionButton(
      tooltip: 'Scan',
      onPressed: () => context.push(Routes.scan),
      child: const Icon(Icons.document_scanner),
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      // Tapping the current tab again returns it to its root.
      onDestinationSelected: (i) =>
          shell.goBranch(i, initialLocation: i == shell.currentIndex),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.apps), label: 'Tools'),
        NavigationDestination(icon: Icon(Icons.folder), label: 'Files'),
        NavigationDestination(icon: Icon(Icons.person), label: 'Me'),
      ],
    ),
  );
}
