import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/dk_layout.dart';
import '../theme/dk_tokens.dart';
import 'dk_icon.dart';
import 'dk_ring.dart';

/// One action of [DkSelectionBar] or [DkViewerBar]: an icon over a label.
class DkBarAction {
  const DkBarAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// Delete: icon and label in `color.danger`.
  final bool destructive;
}

/// What replaces the tab bar in selection mode (UI spec §11.6, §12.1;
/// DK-0172): 64 tall plus the home indicator, `color.surface` with a top
/// hairline, 4–5 actions (icon 24 over a 12/16 label). Its header is
/// `DkTopBar.editing(title: "3 selected", onCancel:, onDone: selectAll,
/// doneLabel: "Select all")`.
class DkSelectionBar extends StatelessWidget {
  const DkSelectionBar({super.key, required this.actions});

  /// Four or five.
  final List<DkBarAction> actions;

  @override
  Widget build(BuildContext context) =>
      _ActionsBar(actions: actions, translucent: false, bold: false);
}

/// The viewer's bottom bar (UI spec §11.6; DK-0178): five actions (Edit,
/// Sign, AI, Tools, Share) on `color.surface` at 94 % with the page blurred
/// behind it. [visible] false slides it away (the viewer hides its chrome
/// on a tap and while scrolling); with Reduce Motion it fades instead.
class DkViewerBar extends StatelessWidget {
  const DkViewerBar({super.key, required this.actions, this.visible = true});

  /// Five: Edit, Sign, AI, Tools, Share.
  final List<DkBarAction> actions;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final m = context.motion(DkMotionKind.standard);
    final bar = _ActionsBar(actions: actions, translucent: true, bold: true);
    // Hidden, it neither shows nor takes taps or screen-reader focus.
    final hidden = ExcludeSemantics(
      excluding: !visible,
      child: IgnorePointer(ignoring: !visible, child: bar),
    );
    return m.crossFade
        ? AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: m.duration,
            curve: m.curve,
            child: hidden,
          )
        : AnimatedSlide(
            offset: visible ? Offset.zero : const Offset(0, 1),
            duration: m.duration,
            curve: m.curve,
            child: hidden,
          );
  }
}

class _ActionsBar extends StatelessWidget {
  const _ActionsBar({
    required this.actions,
    required this.translucent,
    required this.bold,
  });

  final List<DkBarAction> actions;
  final bool translucent;

  /// The viewer's labels are semibold (the export's `600 12px`).
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    Widget bar = DecoratedBox(
      decoration: BoxDecoration(
        color: translucent ? c.surface.withValues(alpha: 0.94) : c.surface,
        border: Border(top: t.divider),
      ),
      // Labels follow the text size up to 125 %, like the tab bar's.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.25,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space.s),
              child: Row(
                children: [
                  for (final a in actions)
                    Expanded(
                      child: _BarButton(action: a, bold: bold),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (translucent) {
      bar = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: bar,
        ),
      );
    }
    return bar;
  }
}

class _BarButton extends StatefulWidget {
  const _BarButton({required this.action, required this.bold});
  final DkBarAction action;
  final bool bold;

  @override
  State<_BarButton> createState() => _BarButtonState();
}

class _BarButtonState extends State<_BarButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final a = widget.action;
    final enabled = a.onPressed != null;
    final ink = a.destructive ? c.danger : c.textPrimary;
    return Semantics(
      button: true,
      enabled: enabled,
      label: a.label,
      excludeSemantics: true,
      // The children are excluded, the tap with them: give it back.
      onTap: a.onPressed,
      child: DkRing(
        side: _focused ? t.focusRing : null,
        radius: t.radius.m,
        child: InkWell(
          onTap: a.onPressed,
          onFocusChange: (v) => setState(() => _focused = v),
          borderRadius: BorderRadius.circular(t.radius.m),
          overlayColor: WidgetStatePropertyAll(t.state.pressed),
          splashFactory: NoSplash.splashFactory,
          child: Opacity(
            opacity: enabled ? 1 : t.state.disabledOpacity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: t.space.xxs,
              children: [
                DkIcon(a.icon, color: a.destructive ? c.danger : c.iconPrimary),
                // A long label ("Seitenübersicht" at large text) shrinks to
                // fit its cell rather than losing letters.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    a.label,
                    style: t.text.caption.copyWith(
                      color: ink,
                      fontWeight: widget.bold ? FontWeight.w600 : null,
                    ),
                    maxLines: 1,
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
