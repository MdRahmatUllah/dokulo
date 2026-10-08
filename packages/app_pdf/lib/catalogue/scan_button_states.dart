import 'package:flutter/material.dart';

import '../components/dk_scan_button.dart';
import '../theme/dk_tokens.dart';

/// DkScanButton: default, pressed, focused and disabled, on the background.
class DkScanButtonGallery extends StatelessWidget {
  const DkScanButtonGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    void tap() {}
    void mode(DkScanMode _) {}
    return Wrap(
      spacing: t.space.l,
      runSpacing: t.space.l,
      children: [
        DkScanButton(onPressed: tap, onMode: mode),
        DkScanButton(onPressed: tap, onMode: mode, showPressed: true),
        DkScanButton(onPressed: tap, onMode: mode, showFocused: true),
        DkScanButton(onPressed: null, onMode: mode),
      ],
    );
  }
}
