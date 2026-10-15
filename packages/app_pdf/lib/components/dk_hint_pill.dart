import 'package:flutter/material.dart';

import '../theme/dk_tokens.dart';
import 'dk_icon.dart';

/// The camera's hint pill (DK-0116; UI spec §11.3, S1): 32 dp tall, 14 dp
/// side padding, `color.cameraChrome` with [text] in `type.labelL`
/// `color.onCamera`. It is a live region, so a screen reader speaks each new
/// hint (§28: "Hint pill text is also spoken"). An [icon] goes before the
/// text (ID card mode's "Turn the card over").
class DkHintPill extends StatelessWidget {
  const DkHintPill(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: t.color.cameraChrome,
          borderRadius: BorderRadius.circular(t.radius.pill),
        ),
        // Centred, but only as big as the text (and the minimum).
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              if (icon case final i?)
                DkIcon(i, size: DkIconSize.m, color: t.color.onCamera),
              Flexible(
                child: Text(
                  text,
                  style: t.text.labelL.copyWith(color: t.color.onCamera),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
