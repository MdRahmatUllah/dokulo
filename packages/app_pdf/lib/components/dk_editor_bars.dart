import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_layout.dart';
import '../theme/dk_tokens.dart';
import 'dk_icon.dart';
import 'dk_icon_button.dart';
import 'dk_ring.dart';

/// One tool of [DkToolStrip].
class DkStripTool {
  const DkStripTool({required this.icon, required this.label});

  final IconData icon;

  /// "Pen", "Highlighter" (UI spec §17.2, V2 edit mode).
  final String label;
}

/// The editor's tool strip (UI spec §11.6, §17.2; DK-0176): 64 tall on
/// `color.surface`; the tools (Pan · Pen · Highlighter · Text · Shapes ·
/// Note · Sign · Eraser), each an icon over a `caption` label, scroll
/// sideways; the selected one sits on a tonal pill. Undo and Redo stay at
/// the right after a divider; disabled when there is nothing to undo.
class DkToolStrip extends StatelessWidget {
  const DkToolStrip({
    super.key,
    required this.tools,
    required this.selected,
    required this.onSelect,
    required this.onUndo,
    required this.onRedo,
  });

  final List<DkStripTool> tools;
  final int selected;
  final ValueChanged<int> onSelect;

  /// Null: nothing to undo (or redo).
  final VoidCallback? onUndo, onRedo;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.color.surface,
        border: Border(top: t.divider),
      ),
      // The tools' ink paints here, above the strip's surface.
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                Expanded(
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.25,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: t.space.xs),
                      children: [
                        for (final (i, tool) in tools.indexed)
                          _StripButton(
                            tool: tool,
                            selected: i == selected,
                            onTap: () => onSelect(i),
                          ),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, height: 32, color: t.color.outline),
                DkIconButton(
                  icon: DkIcons.undo,
                  tooltip: l.common_undo,
                  onPressed: onUndo,
                ),
                DkIconButton(
                  icon: DkIcons.redo,
                  tooltip: l.common_redo,
                  onPressed: onRedo,
                ),
                SizedBox(width: t.space.xs),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StripButton extends StatefulWidget {
  const _StripButton({
    required this.tool,
    required this.selected,
    required this.onTap,
  });

  final DkStripTool tool;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_StripButton> createState() => _StripButtonState();
}

class _StripButtonState extends State<_StripButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final on = widget.selected;
    return Semantics(
      button: true,
      selected: on,
      label: widget.tool.label,
      excludeSemantics: true,
      // The children are excluded, the tap with them: give it back.
      onTap: widget.onTap,
      child: DkRing(
        side: _focused ? t.focusRing : null,
        radius: t.radius.m,
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: (v) => setState(() => _focused = keyboardFocus(v)),
          borderRadius: BorderRadius.circular(t.radius.m),
          overlayColor: WidgetStatePropertyAll(t.state.pressed),
          splashFactory: NoSplash.splashFactory,
          child: SizedBox(
            width: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: t.space.xxs,
              children: [
                Container(
                  width: 36,
                  height: 32,
                  decoration: BoxDecoration(
                    color: on ? c.primaryContainer : null,
                    borderRadius: BorderRadius.circular(t.radius.l),
                  ),
                  child: DkIcon(
                    widget.tool.icon,
                    filled: on,
                    color: on ? c.onPrimaryContainer : c.iconPrimary,
                  ),
                ),
                Text(
                  widget.tool.label,
                  style: t.text.caption.copyWith(
                    color: on ? c.primary : c.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What DkMarkupBar can do with the selected text.
enum DkMarkupAction { copy, highlight, underline, strike, ask }

/// The selected-text bar in the viewer (UI spec §11.8; DK-0202): a 44 tall
/// floating pill (`surfaceRaised`, `elevation.floating`): Copy, Highlight,
/// Underline, Strike, Ask AI (icon 20, labels in `labelM`; Underline and
/// Strike are icon-only with a screen-reader label). [DkMarkupBar.over]
/// places it 8 above the selection, or below near the top.
class DkMarkupBar extends StatelessWidget {
  const DkMarkupBar({super.key, required this.onAction});

  final ValueChanged<DkMarkupAction> onAction;

  /// Places the bar for a selection [selection] (in the coordinates of the
  /// Stack it is put in): centred on it, 8 above, or 8 below when there is
  /// no room above; kept 8 from the sides.
  static Widget over({
    Key? key,
    required Rect selection,
    required ValueChanged<DkMarkupAction> onAction,
  }) => Positioned.fill(
    key: key,
    child: CustomSingleChildLayout(
      delegate: _AboveSelection(selection),
      child: DkMarkupBar(onAction: onAction),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final radius = BorderRadius.circular(t.radius.pill);
    // Labels where they fit; a large text size or a narrow screen gets the
    // icons alone (screen readers still hear every label).
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.25);
    final labelled = [l.markup_copy, l.markup_highlight, l.markup_ask];
    double textWidth(String s) {
      final p = TextPainter(
        text: TextSpan(text: s, style: t.text.labelM),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    // Each labelled item: 8 + icon 20 + 4 + text + 8; icon-only ones 44.
    final full =
        labelled.map((s) => 40 + textWidth(s)).reduce((a, b) => a + b) +
        2 * 44 +
        2 * t.space.xs;
    final room = MediaQuery.sizeOf(context).width - 2 * _AboveSelection.gap;
    final compact = full > room;
    Widget item(
      DkMarkupAction a,
      IconData icon,
      String label, {
      bool iconOnly = false,
      bool accent = false,
    }) => _PillButton(
      icon: icon,
      label: label,
      iconOnly: iconOnly || compact,
      color: accent ? t.color.primary : t.color.textPrimary,
      onTap: () => onAction(a),
    );
    return DecoratedBox(
      decoration: t.surfaceAt(DkLevel.floating, radius: radius),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.25,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                item(DkMarkupAction.copy, DkIcons.copy, l.markup_copy),
                item(
                  DkMarkupAction.highlight,
                  DkIcons.highlighter,
                  l.markup_highlight,
                ),
                item(
                  DkMarkupAction.underline,
                  DkIcons.underline,
                  l.markup_underline,
                  iconOnly: true,
                ),
                item(
                  DkMarkupAction.strike,
                  DkIcons.strike,
                  l.markup_strike,
                  iconOnly: true,
                ),
                item(
                  DkMarkupAction.ask,
                  DkIcons.tool('ask'),
                  l.markup_ask,
                  accent: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatefulWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.iconOnly,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool iconOnly;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      // The children are excluded, the tap with them: give it back.
      onTap: widget.onTap,
      child: DkRing(
        side: _focused ? t.focusRing : null,
        radius: t.radius.l,
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: (v) => setState(() => _focused = keyboardFocus(v)),
          overlayColor: WidgetStatePropertyAll(t.state.pressed),
          splashFactory: NoSplash.splashFactory,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: 44,
              minWidth: widget.iconOnly ? 44 : 0,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.iconOnly ? t.space.xs : t.space.s,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: t.space.xs,
                children: [
                  DkIcon(widget.icon, size: DkIconSize.m, color: widget.color),
                  if (!widget.iconOnly)
                    Text(
                      widget.label,
                      style: t.text.labelM.copyWith(color: widget.color),
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

class _AboveSelection extends SingleChildLayoutDelegate {
  _AboveSelection(this.selection);
  final Rect selection;

  static const gap = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size child) {
    final above = selection.top - gap - child.height;
    final y = above >= gap ? above : selection.bottom + gap;
    final x = selection.center.dx - child.width / 2;
    return Offset(
      x.clamp(gap, math.max(gap, size.width - child.width - gap)),
      y.clamp(0, math.max(0, size.height - child.height)),
    );
  }

  @override
  bool shouldRelayout(_AboveSelection old) => old.selection != selection;
}
