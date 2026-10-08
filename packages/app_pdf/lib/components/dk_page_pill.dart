import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_layout.dart';
import '../theme/dk_tokens.dart';
import 'dk_number_text.dart';

/// The viewer's page indicator (DK-0118; UI spec §11.3): "3 / 12" in
/// `type.labelM`, tabular, on a 28 dp `color.surfaceRaised` pill at 92 %
/// with `elevation.raised`. The viewer places it 16 dp from the
/// bottom-right, above the bottom bar. Screen readers hear "Page 3 of 12".
class DkPagePill extends StatelessWidget {
  const DkPagePill({super.key, required this.page, required this.count});

  /// 1-based.
  final int page, count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final shape = BorderRadius.circular(t.radius.pill);
    return Semantics(
      label: AppLocalizations.of(context).viewer_page_pill(page, count),
      excludeSemantics: true,
      // A label, never a button: taps go through to the page under it.
      child: IgnorePointer(
        child: Container(
          constraints: const BoxConstraints(minHeight: 28),
          padding: EdgeInsets.symmetric(horizontal: t.space.m),
          decoration: t
              .surfaceAt(DkLevel.raised, radius: shape)
              .copyWith(color: t.color.surfaceRaised.withValues(alpha: 0.92)),
          // Centred in the minimum height, without filling the parent.
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: DkNumberText(
              '$page / $count',
              style: t.text.labelM.copyWith(color: t.color.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
