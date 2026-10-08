import 'package:flutter/material.dart';

import '../components/dk_banner.dart';
import '../components/dk_confirm_dialog.dart';
import '../components/dk_icon.dart';
import '../theme/dk_tokens.dart';

void _none() {}

/// DkConfirmDialog (DK-0186): destructive with its icon; a long German-
/// length action that stacks the buttons.
class ConfirmDialogStates extends StatelessWidget {
  const ConfirmDialogStates({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ColoredBox(
      color: t.color.scrim,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: t.space.xl),
        child: Column(
          spacing: t.space.xl,
          children: [
            const DkConfirmDialog(
              title: 'Delete 3 files for good?',
              body: "This can't be undone.",
              action: 'Delete for good',
              destructive: true,
              icon: DkIcons.delete,
              onCancel: _none,
              onAction: _none,
            ),
            const DkConfirmDialog(
              title: 'Replace the original?',
              body: 'The original file is overwritten with the new version.',
              action: 'Replace the original file',
              onCancel: _none,
              onAction: _none,
            ),
            Builder(
              builder: (context) => OutlinedButton(
                onPressed: () => showDkConfirm(
                  context,
                  title: 'Discard this scan?',
                  body: 'All pages of this scan will be deleted.',
                  action: 'Discard',
                  destructive: true,
                ),
                child: const Text('Open as a dialog'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// DkBanner (DK-0192): the four kinds, one with an action.
class BannerStates extends StatelessWidget {
  const BannerStates({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ColoredBox(
      color: t.color.background,
      child: Padding(
        padding: EdgeInsets.all(t.space.l),
        child: Column(
          spacing: t.space.m,
          children: const [
            DkBanner(
              text: '3 scans have no searchable text yet.',
              action: 'Make searchable',
              onAction: _none,
            ),
            DkBanner(
              text: "If you forget the PIN, these files can't be recovered.",
              variant: DkBannerVariant.warning,
            ),
            DkBanner(
              text: "This file is damaged and can't be opened.",
              variant: DkBannerVariant.error,
            ),
            DkBanner(
              text: 'Pro unlocks unlimited use of every tool.',
              variant: DkBannerVariant.pro,
            ),
          ],
        ),
      ),
    );
  }
}
