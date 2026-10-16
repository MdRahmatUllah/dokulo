import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/dk_settings_row.dart';
import '../../components/dk_switch.dart';
import '../../components/dk_tappable.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/prefs_providers.dart';
import '../../providers/theme_providers.dart';
import '../../theme/dk_tokens.dart';
import '../v1_viewer/viewer_screen.dart' show viewerNightKey;

/// M3 · Appearance (DK-0574; UI spec §23.3, me-appearance): the theme as
/// three preview tiles (Light, Dark, System; a mini Home in fixed colours,
/// whatever the current theme), then Viewer night mode. Both apply at once.
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final mode = ref.watch(appThemeModeProvider);
    final night = ref.watch(prefsProvider).value?[viewerNightKey] == true;
    void setNight(bool on) =>
        ref.read(prefsProvider.notifier).set(viewerNightKey, on);
    return Scaffold(
      backgroundColor: t.color.background,
      appBar: DkTopBar(title: l.me_appearance),
      body: ListView(
        padding: EdgeInsets.only(bottom: t.space.l),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              t.space.l,
              t.space.xl,
              t.space.l,
              t.space.s,
            ),
            child: Semantics(
              header: true,
              child: Text(
                l.appearance_theme,
                style: t.text.labelM.copyWith(color: t.color.textSecondary),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.l),
            child: Row(
              spacing: t.space.m,
              children: [
                for (final (m, label) in [
                  (ThemeMode.light, l.me_theme_light),
                  (ThemeMode.dark, l.me_theme_dark),
                  (ThemeMode.system, l.settings_language_system),
                ])
                  Expanded(
                    child: _ThemeTile(
                      mode: m,
                      label: label,
                      selected: m == mode,
                      onTap: () =>
                          ref.read(appThemeModeProvider.notifier).select(m),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(t.space.l, t.space.xl, t.space.l, 0),
            child: DkSettingsGroup(
              children: [
                DkSettingsRow(
                  title: l.appearance_night,
                  description: l.appearance_night_help,
                  trailing: DkSwitch(value: night, onChanged: setNight),
                  onTap: () => setNight(!night),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A theme choice: the 96 × 140 preview with a 3 dp primary ring when
/// chosen (1 dp outline otherwise), the name under it. Read out as a radio.
class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.mode,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    // The previews show their own theme, never the current one.
    final look = mode == ThemeMode.dark ? DkColors.dark : DkColors.light;
    return Semantics(
      container: true,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: DkTappable(
        onTap: onTap,
        radius: t.radius.m,
        builder: (context, pressed) => Column(
          spacing: t.space.s,
          children: [
            Container(
              width: 96,
              height: 140,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: mode == ThemeMode.system ? null : look.background,
                gradient: mode == ThemeMode.system
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0.5, 0.5],
                        colors: [
                          DkColors.light.background,
                          DkColors.dark.background,
                        ],
                      )
                    : null,
                borderRadius: BorderRadius.circular(t.radius.m),
                border: selected
                    ? Border.all(color: c.primary, width: 3)
                    : Border.all(color: c.outline),
              ),
              child: _MiniHome(look: look),
            ),
            Text(
              label,
              style: t.text.labelM.copyWith(color: c.textPrimary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Home in miniature: a title, four tool tiles, three list lines.
class _MiniHome extends StatelessWidget {
  const _MiniHome({required this.look});

  final DkColors look;

  @override
  Widget build(BuildContext context) {
    Widget bar(double height, Color color, {double width = 1}) =>
        FractionallySizedBox(
          widthFactor: width,
          alignment: Alignment.centerLeft,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
    return Column(
      spacing: 6,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bar(8, look.textPrimary, width: 0.5),
        Row(
          spacing: 4,
          children: [
            for (var i = 0; i < 4; i++)
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: look.primaryContainer,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
          ],
        ),
        bar(6, look.outline),
        bar(6, look.outline),
        bar(6, look.outline, width: 0.7),
      ],
    );
  }
}
