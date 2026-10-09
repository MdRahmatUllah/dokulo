import 'package:flutter/material.dart';

import '../theme/dk_tokens.dart';
import 'dk_icon.dart';
import 'dk_loading_spinner.dart';

/// DkButton's sizes (UI spec §11.1).
enum DkButtonSize { large, regular, compact }

/// DkButton's variants (UI spec §11.1). One [primary] per screen.
enum DkButtonVariant {
  primary,
  secondary,
  tertiary,

  /// `color.primaryContainer` with `color.onPrimaryContainer`: the file
  /// action sheet's Open and Share (UI spec §16.3; the export's `.ton2`).
  tonal,

  /// Tertiary in `color.danger` (the export's `.ter.cdg`): Delete in a card.
  tertiaryDanger,
  destructive,
  destructiveSecondary,

  /// On the camera preview: translucent white on any image.
  onCamera,

  /// The camera's main action: white with dark ink (the export's `.wht`):
  /// "Open settings" when camera access is off (S1).
  onCameraPrimary,
}

/// The app's button (DK-0074; UI spec §11.1). The label is verb + object
/// (+ number): "Merge 4 files". `onPressed: null` disables it (40 %).
/// [loading] keeps the label and the width, and swaps the leading icon for a
/// spinner; taps are ignored meanwhile. [expand] fills the width (inside
/// DkActionBar and sheets on phones). Long labels wrap (two lines at most in
/// German at 200 %, by the copy rules), never truncate.
class DkButton extends StatefulWidget {
  const DkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = DkButtonVariant.primary,
    this.size = DkButtonSize.regular,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.focusNode,
    this.autofocus = false,
    this.showPressed = false,
    this.showFocused = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final DkButtonVariant variant;
  final DkButtonSize size;

  /// A leading icon (`DkIcons.…`).
  final IconData? icon;
  final bool loading;
  final bool expand;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Draw the pressed or focused state without a finger or a keyboard: for
  /// the component catalogue and goldens only.
  final bool showPressed, showFocused;

  @override
  State<DkButton> createState() => _DkButtonState();
}

class _DkButtonState extends State<DkButton> {
  var _down = false;
  var _keyFocus = false;

  bool get _pressed => _down || widget.showPressed;
  bool get _focused => _keyFocus || widget.showFocused;

  bool get _enabled => widget.onPressed != null;

  void _press(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  void _activate() {
    if (_enabled && !widget.loading) widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final m = context.motion(DkMotionKind.fast);
    final (
      height,
      padding,
      iconSize,
      gap,
      text,
      radius,
      minWidth,
    ) = switch (widget.size) {
      DkButtonSize.large => (
        52.0,
        24.0,
        DkIconSize.m,
        8.0,
        t.text.labelL,
        t.radius.l,
        120.0,
      ),
      DkButtonSize.regular => (
        44.0,
        20.0,
        DkIconSize.m,
        8.0,
        t.text.labelL,
        t.radius.l,
        96.0,
      ),
      DkButtonSize.compact => (
        36.0,
        14.0,
        DkIconSize.s,
        6.0,
        t.text.labelM,
        t.radius.s,
        64.0,
      ),
    };
    final (fill, ink, border) = switch (widget.variant) {
      DkButtonVariant.primary => (
        _pressed ? c.primaryPressed : c.primary,
        c.onPrimary,
        null,
      ),
      DkButtonVariant.secondary => (
        Colors.transparent,
        c.primary,
        c.outlineStrong,
      ),
      DkButtonVariant.tertiary => (Colors.transparent, c.primary, null),
      DkButtonVariant.tonal => (c.primaryContainer, c.onPrimaryContainer, null),
      DkButtonVariant.tertiaryDanger => (Colors.transparent, c.danger, null),
      DkButtonVariant.destructive => (c.danger, c.onDanger, null),
      DkButtonVariant.destructiveSecondary => (
        Colors.transparent,
        c.danger,
        c.danger,
      ),
      DkButtonVariant.onCamera => (
        c.onCamera.withValues(alpha: 0.16),
        c.onCamera,
        null,
      ),
      // The light theme's ink in both themes: the camera is dark in both.
      DkButtonVariant.onCameraPrimary => (
        c.onCamera,
        DkColors.light.textPrimary,
        null,
      ),
    };
    // Primary darkens when pressed; the others take the pressed overlay.
    final shown = _pressed && widget.variant != DkButtonVariant.primary
        ? Color.alphaBlend(
            widget.variant == DkButtonVariant.onCamera
                ? c.onCamera.withValues(alpha: 0.08)
                : t.state.pressed,
            fill,
          )
        : fill;
    final shape = BorderRadius.circular(radius);

    // The spinner is 20 dp at every size (UI spec §11.1); beside a compact
    // 16 dp icon's place it takes the extra 4 dp from the gap, so the width
    // stays.
    final spinner = DkSpinnerSize.small.dp;
    final spinnerGap = gap - (spinner - iconSize.dp);
    // The platform's indicator (petals on iOS), in the label's colour.
    final leading = widget.loading
        ? DkLoadingSpinner(color: ink)
        : widget.icon == null
        ? null
        : DkIcon(widget.icon!, size: iconSize, color: ink);
    final label = Text(
      widget.label,
      style: text.copyWith(color: ink),
      textAlign: TextAlign.center,
      // Never cut: copy keeps labels to two lines at 200 % (UI spec §27).
      softWrap: true,
    );

    Widget body = Container(
      constraints: BoxConstraints(minHeight: height, minWidth: minWidth),
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: t.space.s),
      decoration: BoxDecoration(
        color: shown,
        borderRadius: shape,
        border: border == null ? null : Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Without an icon the spinner sits in the padding: the width stays.
          if (leading != null && widget.icon != null) ...[
            leading,
            SizedBox(width: widget.loading ? spinnerGap : gap),
          ],
          Flexible(child: label),
        ],
      ),
    );
    if (widget.loading && widget.icon == null) {
      body = Stack(
        alignment: Alignment.centerLeft,
        children: [
          body,
          Positioned(
            left: ((padding - spinner) / 2).clamp(t.space.xxs, padding),
            child: leading!,
          ),
        ],
      );
    }
    // The focus ring: 2 dp, 2 dp off the button, drawn outside its box so
    // focusing doesn't move anything.
    if (_focused) {
      body = Stack(
        clipBehavior: Clip.none,
        children: [
          body,
          Positioned(
            left: -4,
            top: -4,
            right: -4,
            bottom: -4,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius + 4),
                  border: Border.all(color: c.focusRing, width: 2),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Its own node, always: inside a parent with text (a banner) it must not
    // merge into one "text + action" button.
    return Semantics(
      container: true,
      button: true,
      enabled: _enabled,
      label: widget.label,
      excludeSemantics: true,
      onTap: _enabled && !widget.loading ? _activate : null,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        enabled: _enabled,
        mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onShowFocusHighlight: (v) => setState(() => _keyFocus = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => _activate(),
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled && !widget.loading ? (_) => _press(true) : null,
          onTapUp: _enabled ? (_) => _press(false) : null,
          onTapCancel: () => _press(false),
          onTap: _enabled && !widget.loading ? _activate : null,
          // At least 48 dp to touch, whatever the button's own height.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Opacity(
                opacity: _enabled ? 1 : t.state.disabledOpacity,
                child: AnimatedScale(
                  scale: _pressed && !m.crossFade ? 0.98 : 1,
                  duration: m.duration,
                  curve: m.curve,
                  child: body,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
