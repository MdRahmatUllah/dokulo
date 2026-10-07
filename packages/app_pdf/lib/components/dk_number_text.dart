import 'package:flutter/widgets.dart';

/// A number the user compares as it changes (a size, page count, time or
/// percentage): tabular figures, so digits keep their width (UI spec §5;
/// DK-0036). The style defaults to the surrounding text style.
class DkNumberText extends StatelessWidget {
  const DkNumberText(this.text, {super.key, this.style, this.semanticsLabel});

  final String text;
  final TextStyle? style;
  final String? semanticsLabel;

  static const tabular = [FontFeature.tabularFigures()];

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: (style ?? const TextStyle()).copyWith(fontFeatures: tabular),
    semanticsLabel: semanticsLabel,
  );
}
