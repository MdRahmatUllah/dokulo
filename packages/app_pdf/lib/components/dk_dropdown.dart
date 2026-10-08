import 'package:flutter/material.dart';

import '../theme/dk_tokens.dart';
import 'dk_icon.dart';
import 'dk_sheet.dart';
import 'dk_tappable.dart';

/// A choice from a list (DK-0136; UI spec §11.4): it looks like a
/// DkTextField (label above, a 48 dp `color.surfaceSunken` box with the 1 dp
/// `color.outlineStrong` border) with a trailing chevron. Up to five options
/// open a menu under it; more open a DkSheet (medium detent), where a long
/// menu would run off the screen. The keyboard reaches it (focus ring, Enter).
class DkDropdown<T> extends StatefulWidget {
  const DkDropdown({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
    this.error,
  });

  /// The values and their labels, in order.
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T>? onChanged;
  final String? label;
  final String? error;

  /// More than this many options open a sheet instead of a menu.
  static const menuLimit = 5;

  @override
  State<DkDropdown<T>> createState() => _DkDropdownState<T>();
}

class _DkDropdownState<T> extends State<DkDropdown<T>> {
  final _menu = MenuController();

  String get _shown => widget.options
      .firstWhere((o) => o.$1 == widget.value, orElse: () => (widget.value, ''))
      .$2;

  void _pick(T v) => widget.onChanged?.call(v);

  Future<void> _open() async {
    if (widget.onChanged == null) return;
    if (widget.options.length <= DkDropdown.menuLimit) {
      _menu.isOpen ? _menu.close() : _menu.open();
      return;
    }
    final picked = await showDkSheet<T>(
      context,
      title: widget.label,
      detent: DkSheetDetent.medium,
      body: Builder(
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (v, label) in widget.options)
              _OptionTile(
                label: label,
                selected: v == widget.value,
                onTap: () => Navigator.of(context).pop(v),
              ),
          ],
        ),
      ),
    );
    if (picked != null) _pick(picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final error = widget.error;
    final enabled = widget.onChanged != null;
    final box = Semantics(
      button: true,
      enabled: enabled,
      label: [?widget.label, _shown, ?error].join('\n'),
      excludeSemantics: true,
      onTap: enabled ? _open : null,
      child: DkTappable(
        onTap: enabled ? _open : null,
        radius: t.radius.s,
        builder: (context, pressed) => Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: EdgeInsets.only(left: t.space.m, right: t.space.s),
          decoration: BoxDecoration(
            color: pressed
                ? Color.alphaBlend(t.state.pressed, c.surfaceSunken)
                : c.surfaceSunken,
            borderRadius: BorderRadius.circular(t.radius.s),
            border: Border.all(
              color: error == null ? c.outlineStrong : c.danger,
              width: error == null ? 1 : 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: t.space.s),
                  child: Text(
                    _shown,
                    style: t.text.bodyL.copyWith(color: c.textPrimary),
                  ),
                ),
              ),
              DkIcon(DkIcons.expandMore, color: c.iconSecondary),
            ],
          ),
        ),
      ),
    );
    return Opacity(
      opacity: enabled ? 1 : t.state.disabledOpacity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null) ...[
            ExcludeSemantics(
              child: Text(
                widget.label!,
                style: t.text.labelM.copyWith(color: c.textSecondary),
              ),
            ),
            SizedBox(height: t.space.xs),
          ],
          if (widget.options.length <= DkDropdown.menuLimit)
            MenuAnchor(
              controller: _menu,
              style: MenuStyle(
                backgroundColor: WidgetStatePropertyAll(c.surfaceRaised),
              ),
              menuChildren: [
                for (final (v, label) in widget.options)
                  _OptionTile(
                    label: label,
                    selected: v == widget.value,
                    onTap: () {
                      _menu.close();
                      _pick(v);
                    },
                  ),
              ],
              child: box,
            )
          else
            box,
          if (error != null) ...[
            SizedBox(height: t.space.xs),
            ExcludeSemantics(
              child: Row(
                children: [
                  DkIcon(DkIcons.error, size: DkIconSize.s, color: c.danger),
                  SizedBox(width: t.space.xs),
                  Expanded(
                    child: Text(
                      error,
                      style: t.text.caption.copyWith(color: c.danger),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One option in the menu or sheet: the label, and a check when selected.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: DkTappable(
        onTap: onTap,
        radius: 0,
        builder: (context, pressed) => Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 160),
          color: pressed ? t.state.pressed : null,
          padding: EdgeInsets.symmetric(horizontal: t.space.l),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: t.text.bodyL.copyWith(
                    color: selected ? c.primary : c.textPrimary,
                  ),
                ),
              ),
              if (selected)
                DkIcon(DkIcons.check, size: DkIconSize.m, color: c.primary),
            ],
          ),
        ),
      ),
    );
  }
}
