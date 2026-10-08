import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import 'dk_tappable.dart';

/// The scanner's shutter (DK-0080; UI spec §11.1): a 72 dp white ring
/// (4 dp) around a 58 dp white disc, which shrinks to 52 while pressed.
/// [countdown] (0–1) is the auto-capture: a `color.quadStroke` arc fills the
/// ring while the page holds still (`motion.autoCapture`, 0.5 s). Drive it
/// from the same animation that fires the capture, so they end together;
/// the screen announces the capture ("Photo taken") for screen readers.
/// `onPressed: null` (no camera permission) draws it at 40 %.
class DkShutterButton extends StatelessWidget {
  const DkShutterButton({
    super.key,
    required this.onPressed,
    this.countdown = 0,
    this.showPressed = false,
    this.showFocused = false,
  });

  final VoidCallback? onPressed;

  /// The auto-capture's progress; 0 shows no arc.
  final double countdown;

  /// Draw these states without a finger or keyboard: catalogue and goldens.
  final bool showPressed, showFocused;

  static const outer = 72.0, ring = 4.0, disc = 58.0, discPressed = 52.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final m = context.motion(DkMotionKind.fast);
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: AppLocalizations.of(context).scanner_button_shutter,
      excludeSemantics: true,
      onTap: onPressed,
      child: DkTappable(
        onTap: onPressed,
        radius: outer / 2, // a circle: the focus ring follows it
        showPressed: showPressed,
        showFocused: showFocused,
        builder: (context, pressed) {
          final disc = pressed && !m.crossFade
              ? DkShutterButton.discPressed
              : DkShutterButton.disc;
          return Opacity(
            opacity: enabled ? 1 : t.state.disabledOpacity,
            child: CustomPaint(
              painter: _RingPainter(
                ring: c.onCamera,
                arc: c.quadStroke,
                progress: countdown.clamp(0.0, 1.0),
              ),
              child: SizedBox.square(
                dimension: outer,
                child: Center(
                  child: AnimatedContainer(
                    duration: m.duration,
                    curve: m.curve,
                    width: disc,
                    height: disc,
                    decoration: BoxDecoration(
                      color: c.onCamera,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.ring, required this.arc, required this.progress});

  final Color ring, arc;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const w = DkShutterButton.ring;
    final centre = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: centre, radius: (size.width - w) / 2);
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    canvas.drawOval(rect, pen..color = ring);
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        pen..color = arc,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.ring != ring || old.arc != arc;
}
