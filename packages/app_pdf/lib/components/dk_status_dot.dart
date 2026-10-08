import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';

/// What a status dot says.
enum DkStatus { fresh, unsaved, running }

/// A status dot (DK-0112; UI spec §11.3): 8 dp, `color.primary` for new,
/// `color.warning` for unsaved changes; a running job pulses (1 → 35 % and
/// back), steady with Reduce Motion. Screen readers hear its meaning.
class DkStatusDot extends StatefulWidget {
  const DkStatusDot(this.status, {super.key});

  final DkStatus status;

  @override
  State<DkStatusDot> createState() => _DkStatusDotState();
}

class _DkStatusDotState extends State<DkStatusDot>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, value: 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(DkStatusDot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final pulse = widget.status == DkStatus.running && !context.reduceMotion;
    if (pulse && !_pulse.isAnimating) {
      // About one breath a second: in and out over two standard motions.
      _pulse
        ..duration = context.tokens.motion.standard * 2
        ..repeat(reverse: true);
    } else if (!pulse) {
      _pulse.value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final (colour, label) = switch (widget.status) {
      DkStatus.fresh => (t.color.primary, l.status_new),
      DkStatus.unsaved => (t.color.warning, l.status_unsaved),
      DkStatus.running => (t.color.primary, l.status_running),
    };
    return Semantics(
      label: label,
      child: FadeTransition(
        opacity: Tween(begin: 0.35, end: 1.0).animate(_pulse),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
