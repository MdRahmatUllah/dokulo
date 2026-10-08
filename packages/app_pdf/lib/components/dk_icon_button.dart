import 'package:flutter/material.dart';

import '../theme/dk_tokens.dart';
import 'dk_icon.dart';

/// DkIconButton's variants (UI spec §11.1).
enum DkIconButtonVariant {
  /// The bare icon in `color.iconPrimary`.
  plain,

  /// On a 36 dp `color.primaryContainer` circle.
  tonal,

  /// On a 40 dp black circle at 35 %, white icon: over the camera preview.
  onCamera,

  /// A white icon without a circle: on the camera chrome (DkCameraTopBar;
  /// the export's `.ib.cm`).
  onCameraPlain,
}

/// An icon-only button (DK-0076; UI spec §11.1): a 24 dp icon in a 44 dp
/// area, touchable over 48 dp. [tooltip] is required: it is the long-press
/// tooltip and what screen readers say. [selected] fills the icon and puts
/// it on the tonal circle (a toggled favourite). `onPressed: null` disables
/// it (40 %).
class DkIconButton extends StatefulWidget {
  const DkIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.variant = DkIconButtonVariant.plain,
    this.selected,
    this.showPressed = false,
    this.showFocused = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final DkIconButtonVariant variant;

  /// Null for a plain action; true/false for a toggle (screen readers hear
  /// "selected").
  final bool? selected;

  /// Draw these states without a finger or a keyboard: catalogue and goldens.
  final bool showPressed, showFocused;

  @override
  State<DkIconButton> createState() => _DkIconButtonState();
}

class _DkIconButtonState extends State<DkIconButton> {
  var _down = false, _keyFocus = false;

  bool get _enabled => widget.onPressed != null;
  bool get _pressed => _down || widget.showPressed;

  void _press(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final selected = widget.selected ?? false;
    final m = context.motion(DkMotionKind.fast);
    final (double? circle, Color? fill, Color ink) = switch (widget.variant) {
      _
          when selected &&
              widget.variant != DkIconButtonVariant.onCamera &&
              widget.variant != DkIconButtonVariant.onCameraPlain =>
        (36, c.primaryContainer, c.onPrimaryContainer),
      DkIconButtonVariant.plain => (null, null, c.iconPrimary),
      DkIconButtonVariant.tonal => (
        36,
        c.primaryContainer,
        c.onPrimaryContainer,
      ),
      DkIconButtonVariant.onCamera => (
        40,
        c.cameraChrome.withValues(alpha: 0.35),
        c.onCamera,
      ),
      DkIconButtonVariant.onCameraPlain => (null, null, c.onCamera),
    };
    final overlay =
        widget.variant == DkIconButtonVariant.onCamera ||
            widget.variant == DkIconButtonVariant.onCameraPlain
        ? c.onCamera.withValues(alpha: 0.16)
        : t.state.pressed;
    final background = fill == null
        ? (_pressed ? overlay : null)
        : (_pressed ? Color.alphaBlend(overlay, fill) : fill);

    return Semantics(
      button: true,
      enabled: _enabled,
      selected: widget.selected,
      label: widget.tooltip,
      excludeSemantics: true,
      onTap: _enabled ? widget.onPressed : null,
      child: Tooltip(
        message: widget.tooltip,
        excludeFromSemantics: true,
        child: FocusableActionDetector(
          enabled: _enabled,
          onShowFocusHighlight: (v) => setState(() => _keyFocus = v),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) => widget.onPressed?.call(),
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _enabled ? (_) => _press(true) : null,
            onTapUp: _enabled ? (_) => _press(false) : null,
            onTapCancel: () => _press(false),
            onTap: widget.onPressed,
            child: SizedBox.square(
              dimension: 48, // the touch area; the button is 44
              child: Center(
                child: Opacity(
                  opacity: _enabled ? 1 : t.state.disabledOpacity,
                  // The focus ring: 2 dp, 2 dp outside the 44 dp button.
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SizedBox.square(
                        dimension: 44,
                        child: Center(
                          child: AnimatedContainer(
                            duration: m.duration,
                            curve: m.curve,
                            width: circle ?? 44,
                            height: circle ?? 44,
                            decoration: BoxDecoration(
                              color: background,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: DkIcon(
                              widget.icon,
                              filled: selected,
                              color: ink,
                            ),
                          ),
                        ),
                      ),
                      if (_keyFocus || widget.showFocused)
                        Positioned(
                          left: -4,
                          top: -4,
                          right: -4,
                          bottom: -4,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: c.focusRing,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
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
