import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import 'dk_box_frame.dart';

/// A signature placed on a page (UI spec §11.5; DK-0162). Selected: a dashed
/// 1 dp primary box, corner handles (resizing keeps its shape) and a delete
/// ×; unselected: the signature alone.
///
/// A [Positioned] for the page's [Stack] (see [DkBoxFrame]).
class DkSignatureStamp extends StatelessWidget {
  const DkSignatureStamp({
    super.key,
    required this.rect,
    required this.signature,
    this.selected = false,
    this.onChanged,
    this.onTap,
    this.onDelete,
  });

  final Rect rect;

  /// The signature image (drawn, typed or imported), fitted into [rect].
  final Widget signature;
  final bool selected;
  final ValueChanged<Rect>? onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final image = FittedBox(child: signature);
    return DkBoxFrame(
      rect: rect,
      selected: selected,
      keepAspect: true,
      onChanged: onChanged,
      onTap: onTap,
      onDelete: onDelete,
      deleteLabel: l10n.sign_stamp_remove,
      semanticsLabel: l10n.sign_stamp_label,
      child: selected
          ? CustomPaint(
              foregroundPainter: DkDashedBorder(context.tokens.color.primary),
              child: image,
            )
          : image,
    );
  }
}
