import 'package:flutter/widgets.dart';

import '../theme/dk_layout.dart';
import '../theme/dk_tokens.dart';
import 'dk_ring.dart';

/// Something the user taps (chips, cards, rows): a finger, a long press, the
/// keyboard (Tab to it, Enter or Space) and screen readers all reach it. While
/// the keyboard focuses it, the 2 dp `focusRing` sits 2 dp outside its
/// [radius]; [builder] gets whether a finger is down, for the pressed
/// overlay. A null [onTap] disables it.
class DkTappable extends StatefulWidget {
  const DkTappable({
    super.key,
    required this.onTap,
    required this.radius,
    required this.builder,
    this.onLongPress,
    this.showPressed = false,
    this.showFocused = false,
  });

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// The corner radius of what it draws, for the ring.
  final double radius;
  final Widget Function(BuildContext context, bool pressed) builder;

  /// Draw these states without a finger or keyboard: catalogue and goldens.
  final bool showPressed, showFocused;

  @override
  State<DkTappable> createState() => _DkTappableState();
}

class _DkTappableState extends State<DkTappable> {
  var _down = false, _focused = false;

  void _press(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = widget.onTap != null;
    return FocusableActionDetector(
      enabled: enabled,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onTap?.call(),
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _press(true) : null,
        onTapUp: enabled ? (_) => _press(false) : null,
        onTapCancel: () => _press(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: DkRing(
          side: _focused || widget.showFocused ? t.focusRing : null,
          radius: widget.radius,
          child: widget.builder(context, _down || widget.showPressed),
        ),
      ),
    );
  }
}
