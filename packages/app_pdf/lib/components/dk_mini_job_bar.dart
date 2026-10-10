import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import 'dk_icon.dart';
import 'dk_number_text.dart';
import 'dk_tappable.dart';

/// The mini job bar (UI spec §11.6; DK-0174): while jobs run, a 48 dp bar
/// floats 8 from the screen edges above the tab bar or the action bar, on
/// `surfaceRaised` with `elevation.floating`. The tool's [icon], the job's
/// [label] ("Compressing · 18 of 40", `labelM`), an expand chevron, and a
/// 2 dp [progress] line along the bottom. With several [jobs] it says
/// "3 jobs running". Tapping it opens the progress sheet again ([onTap]);
/// [DkJobMorph] morphs between the two.
class DkMiniJobBar extends StatelessWidget {
  const DkMiniJobBar({
    super.key,
    required this.icon,
    required this.label,
    required this.progress,
    required this.onTap,
    this.jobs = 1,
    this.showPressed = false,
    this.showFocused = false,
  });

  final IconData icon;

  /// The running job, as the progress sheet says it.
  final String label;

  /// 0 … 1: the job's, or with several jobs all of them together.
  final double progress;

  final VoidCallback onTap;

  /// How many jobs run; from 2 the label is "{n} jobs running".
  final int jobs;

  /// Draw these states without a finger or keyboard: catalogue and goldens.
  final bool showPressed, showFocused;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final text = jobs > 1
        ? AppLocalizations.of(context).job_running_many(jobs)
        : label;
    final radius = BorderRadius.circular(t.radius.m);
    // Screen readers hear it in 25 % steps (DK-0645), as the progress
    // sheet: a focused bar would otherwise speak at every percent.
    final step = (progress.clamp(0.0, 1.0) * 4).floor() * 25;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.space.s),
      child: Semantics(
        button: true,
        label: text,
        value: '$step %',
        // The children are excluded, the tap with them: give it back.
        excludeSemantics: true,
        onTap: onTap,
        child: DkTappable(
          onTap: onTap,
          radius: t.radius.m,
          showPressed: showPressed,
          showFocused: showFocused,
          builder: (context, pressed) => DecoratedBox(
            decoration: BoxDecoration(
              color: pressed
                  ? Color.alphaBlend(t.state.pressed, c.surfaceRaised)
                  : c.surfaceRaised,
              border: Border.all(color: c.outline),
              borderRadius: radius,
              boxShadow: t.elevation.floating,
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  ConstrainedBox(
                    // At large text the label wraps and the bar grows.
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: t.space.m,
                        right: t.space.xs,
                      ),
                      child: Row(
                        spacing: t.space.s,
                        children: [
                          DkIcon(icon, size: DkIconSize.m, color: c.primary),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: t.space.xs,
                              ),
                              child: DkNumberText(
                                text,
                                style: t.text.labelM.copyWith(
                                  color: c.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          SizedBox.square(
                            dimension: 36,
                            child: DkIcon(
                              DkIcons.expandLess,
                              color: c.iconSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 2,
                    child: FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: ColoredBox(color: c.primary),
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
