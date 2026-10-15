import 'package:flutter/material.dart';

import '../components/dk_signature_pad.dart';
import '../theme/dk_tokens.dart';

/// DkSignaturePad (DK-0206) in a landscape phone's frame (852 × 393): Draw
/// (empty: Save is off), Type with a name, and Image. Live: draw, type,
/// switch tabs and inks.
class SignaturePadStates extends StatelessWidget {
  const SignaturePadStates({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Full size, scrolled sideways: scaled down, its targets would shrink.
    Widget frame(DkSignatureMode mode) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 852,
        height: 393,
        child: DkSignaturePad(
          initialMode: mode,
          name: mode == DkSignatureMode.type ? 'Max Mustermann' : '',
          onCancel: () {},
          onSave: (_, _) {},
          onTakePhoto: () {},
          onChoosePhoto: () {},
        ),
      ),
    );
    return Column(
      spacing: t.space.l,
      children: [for (final mode in DkSignatureMode.values) frame(mode)],
    );
  }
}
