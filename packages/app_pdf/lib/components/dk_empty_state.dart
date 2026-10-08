import 'package:flutter/material.dart';

import '../theme/dk_tokens.dart';
import 'dk_button.dart';
import 'dk_illustration.dart';

/// What a screen shows when it has nothing yet (UI spec §11.7, §26.1;
/// DK-0196): a centred column of the illustration (120, or 80 where §26.1
/// says "small"), 24, the title in `titleM` (a heading), 8, the body in
/// `bodyM` `textSecondary` (at most 280 wide), 24, the action button, 12,
/// an optional secondary button. Search and Trash have no buttons. The
/// illustration is decorative: the title and body say it.
///
/// Where it has a height (a screen's body) it centres itself and scrolls
/// when there isn't room (200 % text); in a scrolling list it just takes
/// the room it needs.
class DkEmptyState extends StatelessWidget {
  const DkEmptyState({
    super.key,
    required this.illustration,
    required this.title,
    required this.body,
    this.illustrationSize = 120,
    this.action,
    this.onAction,
    this.actionIcon,
    this.actionVariant = DkButtonVariant.primary,
    this.secondaryAction,
    this.onSecondaryAction,
  });

  final DkIllustrations illustration;
  final String title;
  final String body;

  /// The illustration's height: 120, or 80 for "small".
  final double illustrationSize;

  /// "Scan a document", "Move files here".
  final String? action;
  final VoidCallback? onAction;

  /// A leading icon on the action (the export's Folder state:
  /// `drive_file_move`).
  final IconData? actionIcon;

  /// Primary by default; the export's Folder state uses Secondary.
  final DkButtonVariant actionVariant;
  final String? secondaryAction;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DkIllustration(
          illustration,
          scale: illustrationSize / illustration.height,
        ),
        SizedBox(height: t.space.xl),
        Semantics(
          header: true,
          child: Text(
            title,
            style: t.text.titleM.copyWith(color: t.color.textPrimary),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: t.space.s),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(
            body,
            style: t.text.bodyM.copyWith(color: t.color.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
        if (action != null) ...[
          SizedBox(height: t.space.xl),
          DkButton(
            label: action!,
            onPressed: onAction,
            icon: actionIcon,
            variant: actionVariant,
          ),
        ],
        if (secondaryAction != null) ...[
          SizedBox(height: t.space.m),
          DkButton(
            label: secondaryAction!,
            onPressed: onSecondaryAction,
            variant: DkButtonVariant.secondary,
          ),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, box) => box.hasBoundedHeight
          ? Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(t.space.l),
                child: column,
              ),
            )
          : Padding(padding: EdgeInsets.all(t.space.l), child: column),
    );
  }
}
