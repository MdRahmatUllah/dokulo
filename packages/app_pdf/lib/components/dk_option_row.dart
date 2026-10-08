import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import 'dk_icon.dart';
import 'dk_tappable.dart';

/// One option of a tool (DK-0138; UI spec §11.4): [title] in `type.titleS`,
/// [help] in `type.bodyM` `color.textSecondary` (two lines at most), the
/// [control] to the right (a switch) or, with [controlBelow], under the text
/// (segmented, slider, chips, fields). 12 dp above and below; a divider
/// under it unless [last].
class DkOptionRow extends StatelessWidget {
  const DkOptionRow({
    super.key,
    required this.title,
    this.help,
    this.control,
    this.controlBelow = false,
    this.last = false,
  });

  final String title;
  final String? help;
  final Widget? control;
  final bool controlBelow;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: t.text.titleS.copyWith(color: c.textPrimary)),
        if (help != null)
          Text(
            help!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.text.bodyM.copyWith(color: c.textSecondary),
          ),
      ],
    );
    return Container(
      padding: EdgeInsets.symmetric(vertical: t.space.m),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.outline)),
      ),
      child: controlBelow || control == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                text,
                if (control != null) ...[SizedBox(height: t.space.s), control!],
              ],
            )
          // A switch with its title is one control for screen readers.
          : MergeSemantics(
              child: Row(
                children: [
                  Expanded(child: text),
                  SizedBox(width: t.space.m),
                  control!,
                ],
              ),
            ),
    );
  }
}

/// "More options" (DK-0138): a row with a chevron that shows or hides
/// [children] (the less-used options of a tool).
class DkMoreOptions extends StatefulWidget {
  const DkMoreOptions({
    super.key,
    required this.children,
    this.initiallyOpen = false,
  });

  final List<Widget> children;
  final bool initiallyOpen;

  @override
  State<DkMoreOptions> createState() => _DkMoreOptionsState();
}

class _DkMoreOptionsState extends State<DkMoreOptions> {
  late var _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final m = context.motion(DkMotionKind.standard);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          child: DkTappable(
            onTap: () => setState(() => _open = !_open),
            radius: t.radius.s,
            builder: (context, pressed) => ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).common_more_options,
                      style: t.text.titleS.copyWith(color: c.primary),
                    ),
                  ),
                  DkIcon(
                    _open ? DkIcons.expandLess : DkIcons.expandMore,
                    color: c.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: m.crossFade ? Duration.zero : m.duration,
          curve: m.curve,
          alignment: Alignment.topCenter,
          child: _open
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: widget.children,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
