import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_layout.dart';
import '../theme/dk_tokens.dart';
import 'dk_icon.dart';
import 'dk_icon_button.dart';
import 'dk_ring.dart';

/// The scanner's flash setting; the top bar cycles through them.
enum DkFlash { off, on, auto }

/// The scanner's top bar (UI spec §19.2; DK-0180): 56 tall below the status
/// bar, on `color.cameraChrome` in both themes, white icons. Close on the
/// left; on the right the flash (cycles Off → On → Auto, the icon with a
/// tiny label), the "Auto" capture pill (outline when off, filled white
/// with dark text when on), the grid toggle and the settings (`tune`).
class DkCameraTopBar extends StatelessWidget {
  const DkCameraTopBar({
    super.key,
    required this.onClose,
    required this.flash,
    required this.onFlash,
    this.onFlashMenu,
    required this.autoCapture,
    required this.onAutoCapture,
    required this.grid,
    required this.onGrid,
    required this.onSettings,
  });

  final VoidCallback onClose;
  final DkFlash flash;

  /// The next setting after a tap: off → on → auto → off.
  final ValueChanged<DkFlash> onFlash;

  /// A long press on flash: the menu with Off, On and Auto (DK-0345).
  final VoidCallback? onFlashMenu;
  final bool autoCapture;
  final ValueChanged<bool> onAutoCapture;
  final bool grid;
  final ValueChanged<bool> onGrid;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    return ColoredBox(
      color: t.color.cameraChrome,
      // The buttons' ink paints here, above the chrome.
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space.xs),
              child: Row(
                children: [
                  DkIconButton(
                    icon: DkIcons.close,
                    tooltip: l.camera_close,
                    onPressed: onClose,
                    variant: DkIconButtonVariant.onCameraPlain,
                  ),
                  const Spacer(),
                  _FlashButton(
                    flash: flash,
                    onLongPress: onFlashMenu,
                    onPressed: () => onFlash(
                      DkFlash.values[(flash.index + 1) % DkFlash.values.length],
                    ),
                  ),
                  _AutoPill(on: autoCapture, onChanged: onAutoCapture),
                  DkIconButton(
                    icon: DkIcons.gridOverlay,
                    tooltip: l.camera_grid,
                    selected: grid,
                    onPressed: () => onGrid(!grid),
                    variant: DkIconButtonVariant.onCameraPlain,
                  ),
                  DkIconButton(
                    icon: DkIcons.filters,
                    tooltip: l.camera_settings,
                    onPressed: onSettings,
                    variant: DkIconButtonVariant.onCameraPlain,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The flash: its icon over a tiny label (Off / On / Auto), 52 wide.
class _FlashButton extends StatefulWidget {
  const _FlashButton({
    required this.flash,
    required this.onPressed,
    this.onLongPress,
  });
  final DkFlash flash;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  @override
  State<_FlashButton> createState() => _FlashButtonState();
}

class _FlashButtonState extends State<_FlashButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final (icon, state) = switch (widget.flash) {
      DkFlash.off => (DkIcons.flashOff, l.camera_flash_off),
      DkFlash.on => (DkIcons.flashOn, l.camera_flash_on),
      DkFlash.auto => (DkIcons.flashAuto, l.camera_flash_auto),
    };
    final ink = t.color.onCamera;
    return Semantics(
      button: true,
      label: '${l.camera_flash}: $state',
      excludeSemantics: true,
      // The children are excluded, the tap with them: give it back.
      onTap: widget.onPressed,
      onLongPress: widget.onLongPress,
      child: DkRing(
        side: _focused ? t.focusRing : null,
        radius: t.radius.m,
        child: InkWell(
          onTap: widget.onPressed,
          onLongPress: widget.onLongPress,
          onFocusChange: (v) => setState(() => _focused = keyboardFocus(v)),
          borderRadius: BorderRadius.circular(t.radius.m),
          overlayColor: WidgetStatePropertyAll(ink.withValues(alpha: 0.16)),
          splashFactory: NoSplash.splashFactory,
          child: SizedBox(
            width: 52,
            height: 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DkIcon(icon, color: ink),
                // The export's tiny label (9 / 10); it follows the text
                // size no further than 125 %.
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.25,
                  child: Text(
                    state,
                    style: t.text.caption.copyWith(
                      color: ink,
                      fontSize: 9,
                      height: 10 / 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Auto-capture: an "Auto" pill, 28 tall; a 1.5 white outline when off,
/// filled white with dark text when on. A 48 target.
class _AutoPill extends StatefulWidget {
  const _AutoPill({required this.on, required this.onChanged});
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  State<_AutoPill> createState() => _AutoPillState();
}

class _AutoPillState extends State<_AutoPill> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final white = t.color.onCamera;
    final radius = BorderRadius.circular(t.radius.pill);
    return Semantics(
      button: true,
      toggled: widget.on,
      label: l.camera_auto_capture,
      excludeSemantics: true,
      // The children are excluded, the tap with them: give it back.
      onTap: () => widget.onChanged(!widget.on),
      child: InkWell(
        onTap: () => widget.onChanged(!widget.on),
        onFocusChange: (v) => setState(() => _focused = keyboardFocus(v)),
        borderRadius: radius,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        child: SizedBox(
          height: 48,
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space.xs),
              child: DkRing(
                side: _focused ? t.focusRing : null,
                radius: 14,
                child: Container(
                  height: 28,
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.on ? white : null,
                    borderRadius: radius,
                    border: Border.all(color: white, width: 1.5),
                  ),
                  child: Text(
                    l.camera_auto,
                    style: t.text.labelM.copyWith(
                      color: widget.on
                          ? t.color.cameraChrome.withValues(alpha: 1)
                          : white,
                    ),
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
