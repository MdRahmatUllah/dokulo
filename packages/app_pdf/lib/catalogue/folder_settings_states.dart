import 'package:flutter/material.dart';

import '../components/dk_folder_card.dart';
import '../components/dk_icon.dart';
import '../components/dk_settings_row.dart';
import '../theme/dk_folder_tags.dart';
import '../theme/dk_tokens.dart';

/// DkFolderCard: list rows (untagged, tagged, drop target) and grid tiles;
/// DkSettingsRow in a group: chevron, value + chevron, switch, description.
class DkFolderSettingsGallery extends StatelessWidget {
  const DkFolderSettingsGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    void tap() {}
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: t.space.s,
      children: [
        DkFolderCard(name: 'Taxes 2026', files: 8, onTap: tap, onMore: tap),
        DkFolderCard(
          name: 'Flat',
          files: 1,
          onTap: tap,
          tag: DkFolderTag.green,
          onMore: tap,
        ),
        DkFolderCard(
          name: 'Work',
          files: 23,
          onTap: tap,
          tag: DkFolderTag.purple,
          dropTarget: true,
        ),
        Row(
          spacing: t.space.m,
          children: [
            for (final tag in [null, DkFolderTag.orange, DkFolderTag.red])
              Expanded(
                child: DkFolderCard(
                  name: 'Receipts',
                  files: 12,
                  onTap: tap,
                  tag: tag,
                  grid: true,
                ),
              ),
          ],
        ),
        DkSettingsGroup(
          title: 'Appearance',
          children: [
            DkSettingsRow(
              title: 'Theme',
              value: 'System',
              icon: DkIcons.settings,
              onTap: tap,
            ),
            DkSettingsRow(
              title: 'Language',
              icon: DkIcons.language,
              onTap: tap,
            ),
            DkSettingsRow(
              title: 'Haptics',
              description: 'A light tap when you select or drop',
              trailing: Switch(value: true, onChanged: (_) {}),
            ),
          ],
        ),
      ],
    );
  }
}
