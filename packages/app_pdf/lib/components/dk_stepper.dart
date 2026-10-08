import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import 'dk_icon.dart';
import 'dk_tappable.dart';
import 'dk_number_text.dart';

/// − value + (DK-0134; UI spec §11.4), for a start number or "every N
/// pages": 36 dp buttons (48 to touch), the value in `type.titleS` with
/// tabular figures. A button at its bound is disabled. Screen readers get
/// one adjustable value.
class DkStepper extends StatelessWidget {
  const DkStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 9999,
    this.label,
  });

  final int value, min, max;
  final ValueChanged<int>? onChanged;

  /// What the value is ("Every N pages"), for screen readers.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final down = onChanged != null && value > min
        ? () => onChanged!(value - 1)
        : null;
    final up = onChanged != null && value < max
        ? () => onChanged!(value + 1)
        : null;
    Widget button(IconData icon, String tip, VoidCallback? tap) => Semantics(
      button: true,
      enabled: tap != null,
      label: tip,
      excludeSemantics: true,
      onTap: tap,
      child: DkTappable(
        onTap: tap,
        radius: 24,
        builder: (context, pressed) => SizedBox.square(
          dimension: 48,
          child: Center(
            child: Opacity(
              opacity: tap == null ? t.state.disabledOpacity : 1,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.outlineStrong),
                ),
                alignment: Alignment.center,
                child: DkIcon(icon, size: DkIconSize.m, color: c.iconPrimary),
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      label: label,
      value: '$value',
      increasedValue: up == null ? null : '${value + 1}',
      decreasedValue: down == null ? null : '${value - 1}',
      onIncrease: up,
      onDecrease: down,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: button(DkIcons.remove, l.common_decrease, down),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 40),
            child: ExcludeSemantics(
              child: DkNumberText(
                '$value',
                style: t.text.titleS.copyWith(color: c.textPrimary),
              ),
            ),
          ),
          ExcludeSemantics(child: button(DkIcons.add, l.common_increase, up)),
        ],
      ),
    );
  }
}
