import 'package:flutter/material.dart';

import '../components/dk_color_row.dart';
import '../components/dk_pin_pad.dart';
import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';

/// DkColorRow with a markup colour selected and with a custom one.
class DkColorRowGallery extends StatelessWidget {
  const DkColorRowGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final swatches = markupSwatches(t, AppLocalizations.of(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DkColorRow(
          swatches: swatches,
          selected: t.markup.blue,
          onChanged: (_) {},
        ),
        DkColorRow(
          swatches: swatches,
          selected: const Color(0xFF6E4AD8),
          onChanged: (_) {},
        ),
      ],
    );
  }
}

/// DkPinPad with the biometric key and a wrong-PIN message.
class DkPinPadGallery extends StatelessWidget {
  const DkPinPadGallery({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: DkPinPad(
      onComplete: (_) {},
      onBiometric: () {},
      biometricLabel: 'Use fingerprint',
      error: 'Wrong PIN',
    ),
  );
}
