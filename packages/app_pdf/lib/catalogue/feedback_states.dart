import 'package:flutter/material.dart';

import '../components/dk_action_bar.dart';
import '../components/dk_empty_state.dart';
import '../components/dk_icon.dart';
import '../components/dk_illustration.dart';
import '../theme/dk_tokens.dart';

void _none() {}

/// DkActionBar (DK-0170): with a caption; a Pro caption with a secondary
/// beside; a secondary above; loading; disabled.
class ActionBarStates extends StatelessWidget {
  const ActionBarStates({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ColoredBox(
      color: t.color.background,
      child: Column(
        spacing: t.space.l,
        children: [
          const DkActionBar(
            label: 'Compress 12 pages',
            onPressed: _none,
            caption: 'About 1.9 MB · 12 pages',
          ),
          const DkActionBar(
            label: 'Black out 14 items',
            onPressed: _none,
            caption: 'Free try · Pro unlocks unlimited use',
            secondaryLabel: 'Review',
            onSecondary: _none,
            secondaryBeside: true,
          ),
          const DkActionBar(
            label: 'Save',
            onPressed: _none,
            secondaryLabel: 'Save a copy',
            onSecondary: _none,
          ),
          DkActionBar(
            label: 'Merge 4 files',
            onPressed: _none,
            icon: DkIcons.tool('merge'),
            loading: true,
          ),
          const DkActionBar(label: 'Merge 4 files', onPressed: null),
        ],
      ),
    );
  }
}

/// DkEmptyState (DK-0196): Files empty, with two buttons.
class EmptyStateStates extends StatelessWidget {
  const EmptyStateStates({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.tokens.color.background,
    child: const SizedBox(
      height: 460,
      child: DkEmptyState(
        illustration: DkIllustrations.folderEmpty,
        title: 'This folder is empty',
        body: 'Move files here from Files or save tool results here.',
        action: 'Move files here',
        onAction: _none,
        secondaryAction: 'Scan a document',
        onSecondaryAction: _none,
      ),
    ),
  );
}
