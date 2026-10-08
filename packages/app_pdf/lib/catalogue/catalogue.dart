import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../theme/dk_tokens.dart';
import '../routes/routes.dart';
import 'button_states.dart';
import 'choice_row_states.dart';
import 'icon_button_states.dart';
import 'next_page_chip_states.dart';
import 'option_row_states.dart';
import 'overlay_states.dart';
import 'feedback_states.dart';
import 'dialog_states.dart';
import 'page_states.dart';
import 'privacy_status_states.dart';
import 'pro_chip_states.dart';
import 'scan_button_states.dart';
import 'bar_states.dart';
import 'shutter_button_states.dart';
import 'switch_segmented_states.dart';
import 'text_field_states.dart';
import 'tool_tile_states.dart';

/// The component catalogue (debug builds only, at `/dev/catalogue`): every
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
  CatalogueEntry('DkButton', '11.1 Buttons', DkButtonGallery()),
  CatalogueEntry('DkPageThumb', '11.5 Pages and thumbnails', PageThumbStates()),
  CatalogueEntry('DkPageTray', '11.5 Pages and thumbnails', PageTrayStates()),
  CatalogueEntry('DkPageGrid', '11.5 Pages and thumbnails', PageGridStates()),
  CatalogueEntry('DkMagnifier', '11.5 Pages and thumbnails', MagnifierStates()),
  CatalogueEntry(
    'DkSheet',
    '11.7 Sheets, dialogs, menus, toasts',
    SheetStates(),
  ),
  CatalogueEntry(
    'DkActionSheet',
    '11.7 Sheets, dialogs, menus, toasts',
    ActionSheetStates(),
  ),
  CatalogueEntry('DkIconButton', '11.1 Buttons', DkIconButtonGallery()),
  CatalogueEntry('DkScanButton', '11.1 Buttons', DkScanButtonGallery()),
  CatalogueEntry(
    'DkProBadge, DkChip',
    '11.3 Badges, chips, indicators',
    DkProBadgeChipGallery(),
  ),
  CatalogueEntry(
    'DkNextChip, DkPageChip',
    '11.3 Badges, chips, indicators',
    DkNextPageChipGallery(),
  ),
  CatalogueEntry('DkActionBar', '11.6 Bars', ActionBarStates()),
  CatalogueEntry(
    'DkEmptyState',
    '11.7 Sheets, dialogs, menus, toasts',
    EmptyStateStates(),
  ),
  CatalogueEntry(
    'DkConfirmDialog',
    '11.7 Sheets, dialogs, menus, toasts',
    ConfirmDialogStates(),
  ),
  CatalogueEntry(
    'DkBanner',
    '11.7 Sheets, dialogs, menus, toasts',
    BannerStates(),
  ),
  CatalogueEntry(
    'DkPrivacyLine, DkStatusDot',
    '11.3 Badges, chips, indicators',
    DkPrivacyStatusGallery(),
  ),
  CatalogueEntry(
    'DkRadioRow, DkCheckboxRow',
    '11.4 Inputs and controls',
    DkChoiceRowsGallery(),
  ),
  CatalogueEntry('DkTopBar', '11.6 Bars', TopBarStates()),
  CatalogueEntry('DkMenu', '11.7 Sheets, dialogs, menus, toasts', MenuStates()),
  CatalogueEntry(
    'DkToast',
    '11.7 Sheets, dialogs, menus, toasts',
    ToastStates(),
  ),
  CatalogueEntry(
    'DkToolTile, DkToolRow',
    '11.2 Tiles and cards',
    DkToolTileGallery(),
  ),
  CatalogueEntry('DkShutterButton', '11.1 Buttons', DkShutterButtonGallery()),
  CatalogueEntry(
    'DkSwitch, DkSegmented',
    '11.4 Inputs and controls',
    DkSwitchSegmentedGallery(),
  ),
  CatalogueEntry('DkTabBar · DkNavRail', '11.6 Bars', TabBarStates()),
  CatalogueEntry(
    'DkOptionRow, DkPositionPicker',
    '11.4 Inputs and controls',
    DkOptionRowGallery(),
  ),
  CatalogueEntry(
    'DkSkeleton · DkLoadingSpinner',
    '11.7 Sheets, dialogs, menus, toasts',
    LoadingStates(),
  ),
  CatalogueEntry(
    'DkTextField, DkPasswordField',
    '11.4 Inputs and controls',
    DkTextFieldGallery(),
  ),
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
            onTap: () => context.push(
              '${Routes.catalogue}/${Uri.encodeComponent(entry.name)}',
            ),
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
    final entry = catalogue.where((e) => e.name == name).firstOrNull;
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('No component called "$name"')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(entry.name)),
      // Both themes are built (not lazily), so a tall entry's Dark half
      // exists before it is scrolled to.
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final tokens in [DkTokens.light, DkTokens.dark])
              Theme(data: dokuloTheme(tokens), child: entry.states),
          ],
        ),
      ),
    );
  }
}
