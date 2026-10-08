import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_layout.dart';
import '../theme/dk_tokens.dart';
import 'dk_ring.dart';

/// A saved signature in the Sign list (UI spec §11.8; DK-0208): 160 × 72,
/// the signature on white (`pageWhite`), `radius.s`, a 1 dp outline. Tap
/// places it; long-press deletes it ([onDelete]: the caller confirms first,
/// §12.4 "remove a saved signature").
class DkSignatureCard extends StatefulWidget {
  const DkSignatureCard({
    super.key,
    required this.signature,
    this.onTap,
    this.onDelete,
  });

  /// The signature image, fitted into the card.
  final Widget signature;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  static const size = Size(160, 72);

  @override
  State<DkSignatureCard> createState() => _DkSignatureCardState();
}

class _DkSignatureCardState extends State<DkSignatureCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = AppLocalizations.of(context);
    final radius = BorderRadius.circular(t.radius.s);
    return Semantics(
      button: widget.onTap != null,
      label: l10n.sign_card_label,
      customSemanticsActions: {
        if (widget.onDelete != null)
          CustomSemanticsAction(label: l10n.sign_card_delete): widget.onDelete!,
      },
      child: DkRing(
        side: _focused ? t.focusRing : null,
        radius: t.radius.s,
        child: Material(
          color: t.color.pageWhite,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: t.color.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onDelete,
            onFocusChange: (v) => setState(() => _focused = v),
            overlayColor: WidgetStatePropertyAll(t.state.pressed),
            splashFactory: NoSplash.splashFactory,
            child: SizedBox.fromSize(
              size: DkSignatureCard.size,
              child: Padding(
                padding: EdgeInsets.all(t.space.s),
                child: ExcludeSemantics(
                  child: FittedBox(child: widget.signature),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
