import 'package:flutter/material.dart';

import '../theme/dk_layout.dart';
import '../theme/dk_tokens.dart';
import 'dk_icon.dart';
import 'dk_number_text.dart';
import 'dk_page_chip.dart';
import 'dk_tappable.dart';

/// One thing Black out found: its masked [preview] ("DE89 •••• •••• 3000"),
/// already masked by the caller, and the [page] it is on (1-based).
class DkDetection {
  const DkDetection({
    required this.preview,
    required this.page,
    required this.checked,
  });

  final String preview;
  final int page;
  final bool checked;
}

/// A category of what Black out found (DK-0220; UI spec §11.8, T2 Black
/// out): a 52 dp row with a checkbox for the whole category, its [icon]
/// (20), the [name] ("IBAN") in `bodyL`, the count and an expand chevron.
/// Expanded, each item follows, 36 in: its own 20 dp checkbox, the masked
/// preview in `type.mono`, and a DkPageChip that jumps to its page.
///
/// The category's checkbox is checked when every item is, empty when none
/// is, and a dash in between; tapping it checks all (or, when all are
/// checked, none). Tapping the rest of the row expands or collapses it.
/// Without [onExpanded] (AI suggestions listed as a count only) there is no
/// chevron.
class DkDetectionGroup extends StatelessWidget {
  const DkDetectionGroup({
    super.key,
    required this.icon,
    required this.name,
    required this.items,
    required this.onCheckedAll,
    required this.onChecked,
    required this.onPage,
    this.expanded = false,
    this.onExpanded,
  });

  final IconData icon;
  final String name;
  final List<DkDetection> items;

  /// The category's checkbox: every item on (true) or off (false).
  final ValueChanged<bool> onCheckedAll;

  /// One item's checkbox, by its index in [items].
  final void Function(int index, bool checked) onChecked;

  /// An item's page chip: jump there.
  final ValueChanged<int> onPage;

  final bool expanded;
  final ValueChanged<bool>? onExpanded;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final on = items.where((i) => i.checked).length;
    final all = on == items.length && items.isNotEmpty;
    final state = all ? true : (on == 0 ? false : null);
    final expand = onExpanded;
    final header = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Row(
        children: [
          _Check(
            value: state,
            size: 24,
            label: name,
            onChanged: () => onCheckedAll(!all),
          ),
          Expanded(
            child: Semantics(
              // The rest of the row opens the list.
              button: expand != null,
              expanded: expand == null ? null : expanded,
              label: '$name, ${items.length}',
              excludeSemantics: true,
              onTap: expand == null ? null : () => expand(!expanded),
              child: DkTappable(
                onTap: expand == null ? null : () => expand(!expanded),
                radius: t.radius.s,
                builder: (context, pressed) => Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  color: pressed ? t.state.pressed : null,
                  padding: EdgeInsets.only(left: t.space.xs, right: t.space.xs),
                  child: Row(
                    spacing: t.space.m,
                    children: [
                      DkIcon(icon, size: DkIconSize.m, color: c.iconPrimary),
                      Expanded(
                        child: Text(
                          name,
                          style: t.text.bodyL.copyWith(color: c.textPrimary),
                        ),
                      ),
                      Container(
                        constraints: const BoxConstraints(minHeight: 22),
                        padding: EdgeInsets.symmetric(horizontal: t.space.s),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.surfaceSunken,
                          borderRadius: BorderRadius.circular(t.radius.pill),
                        ),
                        child: DkNumberText(
                          '${items.length}',
                          style: t.text.caption.copyWith(
                            color: c.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (expand != null)
                        DkIcon(
                          expanded ? DkIcons.expandLess : DkIcons.expandMore,
                          size: DkIconSize.m,
                          color: c.iconSecondary,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: t.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          if (expanded && expand != null)
            for (final (i, item) in items.indexed)
              Padding(
                // Under the name: past the category's checkbox.
                padding: EdgeInsets.only(left: t.space.xl),
                child: Row(
                  spacing: t.space.s,
                  children: [
                    Expanded(
                      child: MergeSemantics(
                        child: DkTappable(
                          onTap: () => onChecked(i, !item.checked),
                          radius: t.radius.s,
                          builder: (context, pressed) => Container(
                            constraints: const BoxConstraints(minHeight: 48),
                            color: pressed ? t.state.pressed : null,
                            child: Row(
                              children: [
                                _Check(
                                  value: item.checked,
                                  size: 20,
                                  onChanged: () => onChecked(i, !item.checked),
                                ),
                                Expanded(
                                  child: Text(
                                    item.preview,
                                    style: t.text.mono.copyWith(
                                      color: c.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    DkPageChip(page: item.page, onTap: () => onPage(item.page)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// A [size] dp checkbox in a 48 slot: `primary` when on, a dash when some
/// are, a 2 dp `outlineStrong` ring when off. In a row the keyboard reaches
/// the row; a standalone one ([label]) takes the focus itself.
class _Check extends StatelessWidget {
  const _Check({
    required this.value,
    required this.size,
    required this.onChanged,
    this.label,
  });

  final bool? value;
  final double size;
  final VoidCallback onChanged;

  /// For a checkbox that stands alone (the category's).
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.color;
    final box = SizedBox.square(
      dimension: kMinInteractiveDimension,
      child: Transform.scale(
        scale: size / 18, // Material draws 18 dp.
        child: Checkbox(
          value: value,
          tristate: true,
          onChanged: (_) => onChanged(),
          fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? c.primary
                : Colors.transparent,
          ),
          checkColor: c.onPrimary,
          side: WidgetStateBorderSide.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? BorderSide.none
                : BorderSide(color: c.outlineStrong, width: 2),
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
    final excluded = ExcludeFocus(child: box);
    if (label == null) return excluded;
    // Standalone: the 2 dp focus ring, Enter and Space.
    // One node: the name, the checked state, the tap.
    return MergeSemantics(
      child: Semantics(
        label: label,
        child: DkTappable(
          onTap: onChanged,
          radius: kMinInteractiveDimension / 2,
          builder: (context, pressed) => excluded,
        ),
      ),
    );
  }
}
