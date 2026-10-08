import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/dk_tokens.dart';

/// An on/off switch (DK-0128; UI spec §11.4) in the platform's look: iOS
/// 51 × 31, Android Material 3; on in `color.primary`. Give [label] when the
/// switch stands without a row title (DkOptionRow labels it otherwise).
// ponytail: the iOS switch is UISwitch's 51 × 31, under the 44 target: it
// lives in a DkOptionRow, whose whole row is the target. A standalone iOS
// switch would need a 44 dp hit band around it.
class DkSwitch extends StatelessWidget {
  const DkSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.color;
    final ios = switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
    final control = ios
        ? CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: c.primary,
          )
        : Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: c.primary,
            activeThumbColor: c.onPrimary,
            inactiveTrackColor: c.surfaceSunken,
            inactiveThumbColor: c.outlineStrong,
            trackOutlineColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected)
                  ? c.primary
                  : c.outlineStrong,
            ),
          );
    return label == null ? control : Semantics(label: label, child: control);
  }
}
