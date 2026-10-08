import 'package:flutter/widgets.dart';

/// A file name on one line, shortened in the middle so its end and
/// extension stay visible: "Mietvertrag_Mü…_2026.pdf" (UI spec §5 Rules;
/// DK-0037). Titles shorten at the end instead (`overflow: ellipsis`).
///
/// It cuts between characters as the user sees them (grapheme clusters), so
/// an emoji, an accent or an Arabic letter is never split, and it measures
/// with the platform's text scale. Screen readers read the whole name.
class DkMiddleEllipsisText extends StatelessWidget {
  const DkMiddleEllipsisText(this.name, {super.key, this.style});

  final String name;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(this.style);
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, box) => Semantics(
        label: name,
        child: ExcludeSemantics(
          child: Text(
            middleEllipsis(
              name,
              fits: (text) {
                final painter = TextPainter(
                  text: TextSpan(text: text, style: style),
                  textDirection: direction,
                  textScaler: scaler,
                  maxLines: 1,
                )..layout();
                final fits = painter.width <= box.maxWidth;
                painter.dispose();
                return fits;
              },
            ),
            style: style,
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}

/// [name] shortened in the middle to the longest form that [fits]: the head,
/// "…", and a tail that always keeps the extension (".pdf"). Exposed for
/// tests and for places that draw text themselves.
String middleEllipsis(String name, {required bool Function(String) fits}) {
  if (fits(name)) return name;
  final chars = name.characters.toList();
  final dot = name.lastIndexOf('.');
  // The extension in characters, at most 6 (".jpeg"), else none.
  final ext = dot > 0 && name.length - dot <= 6
      ? name.substring(dot).characters.length
      : 0;
  String cut(int keep) {
    final tail = keep ~/ 2 < ext ? ext : keep ~/ 2;
    final head = keep - tail;
    return '${chars.take(head).join()}…'
        '${chars.skip(chars.length - tail).join()}';
  }

  // The most characters that fit; never fewer than "…" and the extension.
  var lo = ext, hi = chars.length - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) ~/ 2;
    if (fits(cut(mid))) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return cut(lo);
}

/// Body text no wider than a readable line: about 70 characters, and at
/// most 640 dp on tablets (UI spec §5 Rules; DK-0037). On a phone the screen
/// is narrower anyway, so it changes nothing there.
class DkReadableWidth extends StatelessWidget {
  const DkReadableWidth({super.key, required this.child});

  /// The spec's text column on tablets.
  static const maxWidth = 640.0;

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
