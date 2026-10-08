import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_layout.dart';
import '../theme/dk_tokens.dart';
import 'dk_icon.dart';
import 'dk_ring.dart';

/// One destination of [DkTabBar] and [DkNavRail].
class DkTabItem {
  const DkTabItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// The phone's tab bar (UI spec §11.6; DK-0166): 64 tall plus the home
/// indicator, `color.surface` with a top hairline; four destinations (icon
/// 24 + `labelM`) around an 88 gap for the Scan button, whose "Scan" label
/// sits in the gap. Selected: the filled icon and the label in primary;
/// the others in `iconSecondary` / `textSecondary`.
///
/// The Scan button is the Scaffold's `floatingActionButton` at
/// [DkTabBar.scanLocation] (its centre 12 above the bar), so all of it,
/// the part above the bar too, takes taps.
class DkTabBar extends StatelessWidget {
  const DkTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
  }) : assert(items.length == 4, 'two tabs on each side of Scan');

  final List<DkTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const height = 64.0, scanGap = 88.0;

  /// How far the labels follow the system text size.
  static const maxTextScale = 1.25;

  /// Where the Scaffold puts the Scan button: centred, 12 above the bar.
  static const FloatingActionButtonLocation scanLocation = _ScanLocation();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget tab(int i) => Expanded(
      child: _Destination(
        item: items[i],
        selected: i == currentIndex,
        onTap: () => onSelect(i),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.color.surface,
        border: Border(top: BorderSide(color: t.color.outline)),
      ),
      // Labels grow to 125 % at most (the design export's 200 % frame: 13 →
      // 16 px), as tab bars do, so the bar keeps its height.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: maxTextScale,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: height,
            child: Row(
              children: [
                tab(0),
                tab(1),
                SizedBox(
                  width: scanGap,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: t.space.s),
                      // The Scan button says "Scan" to screen readers.
                      child: ExcludeSemantics(
                        child: Text(
                          AppLocalizations.of(context).shell_button_scan,
                          style: t.text.labelM.copyWith(color: t.color.primary),
                        ),
                      ),
                    ),
                  ),
                ),
                tab(2),
                tab(3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanLocation extends StandardFabLocation with FabCenterOffsetX {
  const _ScanLocation();

  @override
  double getOffsetY(ScaffoldPrelayoutGeometry geometry, double adjustment) =>
      // contentBottom is the bar's top edge.
      geometry.contentBottom -
      geometry.floatingActionButtonSize.height / 2 -
      12;

  @override
  String toString() => 'DkTabBar.scanLocation';
}

/// The tablet's navigation rail (UI spec §11.6; DK-0168), from 840 dp: 80
/// wide, `color.surface` with a right hairline; the Scan button as a 56
/// rounded square at the top, then the four destinations (a 56 × 32 pill
/// with the icon, the label under it). Selected: a `primaryContainer` pill
/// with the filled icon and the label in primary.
class DkNavRail extends StatelessWidget {
  const DkNavRail({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    required this.onScan,
    this.onScanMenu,
  });

  final List<DkTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onScan;

  /// A long press on Scan: the mode menu, anchored to the given context.
  final void Function(BuildContext anchor)? onScanMenu;

  static const width = 80.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.outline)),
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: DkTabBar.maxTextScale,
        child: SafeArea(
          right: false,
          child: SizedBox(
            width: width,
            child: Column(
              spacing: t.space.s,
              children: [
                SizedBox(height: t.space.xl),
                Builder(
                  builder: (anchor) => _RailScan(
                    label: l.shell_button_scan,
                    onTap: onScan,
                    onLongPress: onScanMenu == null
                        ? null
                        : () => onScanMenu!(anchor),
                  ),
                ),
                SizedBox(height: t.space.s),
                for (var i = 0; i < items.length; i++)
                  _Destination(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onSelect(i),
                    pill: true,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailScan extends StatefulWidget {
  const _RailScan({required this.label, required this.onTap, this.onLongPress});
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<_RailScan> createState() => _RailScanState();
}

class _RailScanState extends State<_RailScan> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final radius = BorderRadius.circular(t.radius.l);
    return Semantics(
      button: true,
      label: widget.label,
      child: DkRing(
        side: _focused ? t.focusRing : null,
        radius: t.radius.l,
        // The floating shadow outside, the primary fill and ink inside.
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: t.elevation.floating,
          ),
          child: Material(
            color: c.primary,
            borderRadius: radius,
            child: InkWell(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              onFocusChange: (v) => setState(() => _focused = v),
              borderRadius: radius,
              overlayColor: WidgetStatePropertyAll(t.state.pressed),
              splashFactory: NoSplash.splashFactory,
              child: SizedBox.square(
                dimension: 56,
                child: DkIcon(
                  DkIcons.scan,
                  size: DkIconSize.xl,
                  color: c.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tab or rail destination: the icon (on a pill in the rail) over the
/// label; a 48 dp target at least; selected for screen readers.
class _Destination extends StatefulWidget {
  const _Destination({
    required this.item,
    required this.selected,
    required this.onTap,
    this.pill = false,
  });

  final DkTabItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool pill;

  @override
  State<_Destination> createState() => _DestinationState();
}

class _DestinationState extends State<_Destination> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final on = widget.selected;
    final iconColor = on
        ? (widget.pill ? c.onPrimaryContainer : c.primary)
        : c.iconSecondary;
    final icon = DkIcon(widget.item.icon, filled: on, color: iconColor);
    return Semantics(
      button: true,
      selected: on,
      label: widget.item.label,
      // The children are excluded, the tap with them: give it back.
      excludeSemantics: true,
      onTap: widget.onTap,
      child: DkRing(
        side: _focused ? t.focusRing : null,
        radius: t.radius.m,
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: (v) => setState(() => _focused = v),
          borderRadius: BorderRadius.circular(t.radius.m),
          overlayColor: WidgetStatePropertyAll(t.state.pressed),
          splashFactory: NoSplash.splashFactory,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: 48,
              minWidth: widget.pill ? 64 : 48,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: t.space.xs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: widget.pill ? t.space.xs : t.space.xxs,
                children: [
                  if (widget.pill)
                    Container(
                      width: 56,
                      height: 32,
                      decoration: BoxDecoration(
                        color: on ? c.primaryContainer : null,
                        borderRadius: BorderRadius.circular(t.radius.l),
                      ),
                      child: icon,
                    )
                  else
                    icon,
                  // A long label ("Werkzeuge" at large text) shrinks to fit
                  // its cell rather than losing letters.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.item.label,
                      style: t.text.labelM.copyWith(
                        color: on ? c.primary : c.textSecondary,
                      ),
                      maxLines: 1,
                    ),
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
