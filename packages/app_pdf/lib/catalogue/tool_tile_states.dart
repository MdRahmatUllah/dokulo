import 'package:flutter/material.dart';

import '../components/dk_tool_tile.dart';
import '../theme/dk_tokens.dart';

/// DkToolTile (free, Pro, new, pressed) in a four-column row, and DkToolRow
/// (plain, with description, Pro).
class DkToolTileGallery extends StatelessWidget {
  const DkToolTileGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    void tap() {}
    final now = DateTime(2026, 10, 8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: t.space.m,
      children: [
        Row(
          children: [
            for (final tile in [
              DkToolTile(toolId: 'compress', onTap: tap),
              DkToolTile(toolId: 'redact', onTap: tap),
              DkToolTile(
                toolId: 'smartsplit',
                onTap: tap,
                addedOn: DateTime(2026, 10, 1),
                now: now,
              ),
              DkToolTile(toolId: 'merge', onTap: tap, showPressed: true),
            ])
              Expanded(child: tile),
          ],
        ),
        DkToolRow(toolId: 'merge', onTap: tap),
        DkToolRow(toolId: 'compress', onTap: tap, showDescription: true),
        DkToolRow(toolId: 'summarize', onTap: tap, showDescription: true),
      ],
    );
  }
}
