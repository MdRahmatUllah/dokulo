import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';

/// A page reference in an AI answer (DK-0108; UI spec §11.3): "p. 3" /
/// "S. 3" in `type.labelM` on a 22 dp `color.primaryContainer` pill; 44 dp
/// to touch. A tap jumps the viewer to that page ([onTap]).
class DkPageChip extends StatelessWidget {
  const DkPageChip({super.key, required this.page, required this.onTap});

  /// 1-based.
  final int page;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l.viewer_page_chip_go(page),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Container(
              constraints: const BoxConstraints(minHeight: 22),
              padding: EdgeInsets.symmetric(horizontal: t.space.s),
              decoration: BoxDecoration(
                color: t.color.primaryContainer,
                borderRadius: BorderRadius.circular(t.radius.pill),
              ),
              // Centred in the minimum height, without filling the parent.
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  l.viewer_page_chip(page),
                  style: t.text.labelM.copyWith(
                    color: t.color.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
