import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import 'dk_button.dart';
import 'dk_icon.dart';
import 'dk_slider.dart';
import 'dk_tappable.dart';

/// A colour to pick, with its spoken name.
typedef DkSwatch = ({Color color, String name});

/// The markup colours with their names (Yellow / Gelb …), for DkColorRow.
List<DkSwatch> markupSwatches(DkTokens t, AppLocalizations l) => [
  (color: t.markup.yellow, name: l.colour_yellow),
  (color: t.markup.green, name: l.colour_green),
  (color: t.markup.blue, name: l.colour_blue),
  (color: t.markup.pink, name: l.colour_pink),
  (color: t.markup.red, name: l.colour_red),
  (color: t.markup.black, name: l.colour_black),
];

/// A row of colours (DK-0142; UI spec §11.4): 32 dp swatches with a 2 dp
/// outline; the selected one has a 3 dp `color.primary` ring and a check;
/// the last item, "Custom", opens a hue and brightness picker. Each swatch
/// says its name.
class DkColorRow extends StatelessWidget {
  const DkColorRow({
    super.key,
    required this.swatches,
    required this.selected,
    required this.onChanged,
    this.custom = true,
  });

  final List<DkSwatch> swatches;
  final Color selected;
  final ValueChanged<Color> onChanged;

  /// Show the "Custom" swatch at the end.
  final bool custom;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final isCustom = !swatches.any((s) => s.color == selected);
    Widget swatch({
      required String name,
      required bool on,
      required VoidCallback onTap,
      Color? fill,
      Widget? child,
    }) {
      // The check reads on light and dark fills alike.
      final ink = fill == null || fill.computeLuminance() > 0.4
          ? c.textPrimary
          : c.pageWhite;
      return Semantics(
        button: true,
        inMutuallyExclusiveGroup: true,
        selected: on,
        label: name,
        excludeSemantics: true,
        onTap: onTap,
        child: DkTappable(
          onTap: onTap,
          radius: 22,
          builder: (context, pressed) => SizedBox.square(
            dimension: 44,
            child: Center(
              child: Container(
                width: 32 + (on ? 8 : 0),
                height: 32 + (on ? 8 : 0),
                padding: EdgeInsets.all(on ? 1 : 0),
                decoration: on
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: c.primary, width: 3),
                      )
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fill ?? c.surface,
                    border: Border.all(color: c.outline, width: 2),
                  ),
                  alignment: Alignment.center,
                  child:
                      child ??
                      (on
                          ? DkIcon(
                              DkIcons.check,
                              size: DkIconSize.s,
                              color: ink,
                            )
                          : null),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: t.space.xxs,
      children: [
        for (final s in swatches)
          swatch(
            name: s.name,
            on: s.color == selected,
            fill: s.color,
            onTap: () => onChanged(s.color),
          ),
        if (custom)
          swatch(
            name: l.colour_custom,
            on: isCustom,
            fill: isCustom ? selected : null,
            onTap: () async {
              final picked = await showDkColorPicker(context, selected);
              if (picked != null) onChanged(picked);
            },
            child: isCustom
                ? null
                : DkIcon(
                    DkIcons.palette,
                    size: DkIconSize.s,
                    color: c.iconSecondary,
                  ),
          ),
      ],
    );
  }
}

/// The simple custom colour picker: hue and brightness sliders over a
/// preview, in a bottom sheet. Null when dismissed.
Future<Color?> showDkColorPicker(BuildContext context, Color initial) {
  final hsv = HSVColor.fromColor(initial);
  var hue = hsv.hue, value = hsv.value;
  return showModalBottomSheet<Color>(
    context: context,
    backgroundColor: context.tokens.color.surface,
    builder: (context) {
      final t = context.tokens;
      final l = AppLocalizations.of(context);
      return StatefulBuilder(
        builder: (context, set) {
          final colour = HSVColor.fromAHSV(1, hue, 1, value).toColor();
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.all(t.space.l),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: t.space.m,
                children: [
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: colour,
                      borderRadius: BorderRadius.circular(t.radius.s),
                      border: Border.all(color: t.color.outline),
                    ),
                  ),
                  DkSlider(
                    title: l.colour_hue,
                    value: hue,
                    max: 359,
                    format: (v) => '${v.round()}°',
                    onChanged: (v) => set(() => hue = v),
                  ),
                  DkSlider(
                    title: l.colour_brightness,
                    value: value,
                    format: (v) => '${(v * 100).round()} %',
                    onChanged: (v) => set(() => value = v),
                  ),
                  DkButton(
                    label: l.common_done,
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(colour),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
