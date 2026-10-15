import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import 'dk_action_sheet.dart';
import 'dk_icon.dart';
import 'dk_menu.dart';

/// What the scanner opens in (UI spec §19.1): the Scan button's long-press
/// menu, in this order.
enum DkScanMode {
  document,
  idCard,
  book,
  batch,

  /// Photos from the gallery instead of the camera.
  importPhotos;

  IconData get icon => switch (this) {
    document => DkIcons.scanDocument,
    idCard => DkIcons.scanIdCard,
    book => DkIcons.scanBook,
    batch => DkIcons.scanBatch,
    importPhotos => DkIcons.importPhotos,
  };

  String label(AppLocalizations l) => switch (this) {
    document => l.scan_mode_document,
    idCard => l.scan_mode_idcard,
    book => l.scan_mode_book,
    batch => l.scan_mode_batch,
    importPhotos => l.scan_mode_import,
  };
}

/// The raised Scan button in the middle of the tab bar (DK-0078; UI spec
/// §11.1): a 64 dp `color.primary` circle with the scanner icon, the floating
/// shadow and a 4 dp `color.background` ring, then "Scan" / "Scannen" under
/// it. A tap scans a document; a long press opens the mode menu above it.
/// The tab bar places it, its centre 12 dp above the bar's top edge.
class DkScanButton extends StatefulWidget {
  const DkScanButton({
    super.key,
    required this.onPressed,
    required this.onMode,
    this.showLabel = true,
    this.showPressed = false,
    this.showFocused = false,
  });

  final VoidCallback? onPressed;

  /// A mode picked from the long-press menu.
  final ValueChanged<DkScanMode> onMode;

  /// The label under the bar line; off where the bar draws its own.
  final bool showLabel;

  /// Draw these states without a finger or keyboard: catalogue and goldens.
  final bool showPressed, showFocused;

  /// The circle and its ring.
  static const diameter = 64.0, ring = 4.0;

  @override
  State<DkScanButton> createState() => _DkScanButtonState();
}

class _DkScanButtonState extends State<DkScanButton> {
  var _down = false;
  var _keyFocus = false;

  bool get _enabled => widget.onPressed != null;
  bool get _pressed => _down || widget.showPressed;

  void _press(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  /// The modes in a DkMenu (UI spec §11.7, the home-scanmenu frame): the
  /// four camera modes, then Import photos in a group of its own.
  void _openMenu() {
    _press(false);
    if (!_enabled) return;
    final l = AppLocalizations.of(context);
    DkAction action(DkScanMode mode) => DkAction(
      icon: mode.icon,
      label: mode.label(l),
      onTap: () => widget.onMode(mode),
    );
    showDkMenu(
      context,
      groups: [
        [
          for (final mode in DkScanMode.values)
            if (mode != DkScanMode.importPhotos) action(mode),
        ],
        [action(DkScanMode.importPhotos)],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    // Pressed: in quickly; released: back to 1.0 with the emphasis overshoot.
    final m = context.motion(
      _pressed ? DkMotionKind.fast : DkMotionKind.emphasis,
    );
    const outer = DkScanButton.diameter + 2 * DkScanButton.ring;

    final circle = Container(
      width: outer,
      height: outer,
      decoration: BoxDecoration(
        color: c.primary,
        shape: BoxShape.circle,
        border: Border.all(
          color: c.background,
          width: DkScanButton.ring,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
        boxShadow: t.elevation.floating,
      ),
      alignment: Alignment.center,
      child: DkIcon(DkIcons.scan, size: DkIconSize.xl, color: c.onPrimary),
    );

    final button = Semantics(
      button: true,
      enabled: _enabled,
      label: l.shell_button_scan,
      onLongPressHint: l.shell_button_scan_hint,
      excludeSemantics: true,
      onTap: widget.onPressed,
      onLongPress: _enabled ? _openMenu : null,
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
          onLongPress: _enabled ? _openMenu : null,
          child: AnimatedScale(
            scale: _pressed && !m.crossFade ? 0.94 : 1,
            duration: m.duration,
            curve: m.curve,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                circle,
                if (_keyFocus || widget.showFocused)
                  Positioned.fill(
                    left: -4,
                    top: -4,
                    right: -4,
                    bottom: -4,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: c.focusRing, width: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    // Disabled: the circle and the label at 40 %.
    return Opacity(
      opacity: _enabled ? 1 : t.state.disabledOpacity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          button,
          if (widget.showLabel) ...[
            SizedBox(height: t.space.xs),
            // The button already says "Scan".
            ExcludeSemantics(
              child: Text(
                l.shell_button_scan,
                style: t.text.labelM.copyWith(color: c.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
