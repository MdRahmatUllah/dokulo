import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../theme/dk_tokens.dart';
import 'page_states.dart';

/// The component catalogue (debug builds only, at `/dev/components`): every
/// Dk component with each variant and state, in Light and Dark. A component
/// task adds one entry here; its golden test renders the same states widget,
/// so the catalogue shows exactly what is tested.
///
/// Developer tooling, never shown to users: its names aren't translated
/// (tools/check_l10n.py skips this folder).
class CatalogueEntry {
  const CatalogueEntry(this.name, this.section, this.states);

  /// The component, e.g. `DkPageThumb`.
  final String name;

  /// Its section in UI spec §11, e.g. "11.5 Pages and thumbnails".
  final String section;
  final Widget states;
}

const catalogue = [
  CatalogueEntry('DkPageThumb', '11.5 Pages and thumbnails', PageThumbStates()),
  CatalogueEntry('DkPageTray', '11.5 Pages and thumbnails', PageTrayStates()),
];

/// The list of components; tap one to see its states.
class CatalogueScreen extends StatelessWidget {
  const CatalogueScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Components')),
    body: ListView(
      children: [
        for (final entry in catalogue)
          ListTile(
            title: Text(entry.name),
            subtitle: Text(entry.section),
            onTap: () => context.push('/dev/components/${entry.name}'),
          ),
      ],
    ),
  );
}

/// One component's states in Light, then in Dark.
class CatalogueEntryScreen extends StatelessWidget {
  const CatalogueEntryScreen(this.name, {super.key});
  final String name;

  @override
  Widget build(BuildContext context) {
    final entry = catalogue.firstWhere((e) => e.name == name);
    return Scaffold(
      appBar: AppBar(title: Text(entry.name)),
      body: ListView(
        children: [
          for (final tokens in [DkTokens.light, DkTokens.dark])
            Theme(data: dokuloTheme(tokens), child: entry.states),
        ],
      ),
    );
  }
}
