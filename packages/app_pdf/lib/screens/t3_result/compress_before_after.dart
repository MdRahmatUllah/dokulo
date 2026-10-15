import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/dk_segmented.dart';
import '../../components/dk_skeleton.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dk_tokens.dart';
import '../t2_tool/tool_options_providers.dart';

/// Compress's T3 look (DK-0464; tool-shell-result): Before · After, each the
/// same 200 × 200 area of page 1 at 200 % zoom, to judge what the
/// compression did to text and pictures.
class CompressBeforeAfter extends ConsumerStatefulWidget {
  const CompressBeforeAfter({
    super.key,
    required this.before,
    required this.after,
  });

  /// The input and the output, as paths.
  final String before, after;

  /// The crop's side, and where on the page it starts (a fraction of the
  /// width and height: past the margin, into the text).
  static const side = 200.0;
  static const origin = Alignment(-0.7, -0.75);

  @override
  ConsumerState<CompressBeforeAfter> createState() =>
      _CompressBeforeAfterState();
}

class _CompressBeforeAfterState extends ConsumerState<CompressBeforeAfter> {
  var _after = true;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final path = _after ? widget.after : widget.before;
    // 144 dpi: 200 % of the page's 72 points per inch.
    final image = ref.watch(pdfPageImageProvider(path)).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: t.space.s,
      children: [
        DkSegmented<bool>(
          segments: [(false, l.compress_before), (true, l.compress_after)],
          selected: _after,
          onChanged: (v) => setState(() => _after = v),
        ),
        Center(
          child: Semantics(
            image: true,
            label: _after ? l.compress_after : l.compress_before,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(t.radius.m),
              child: SizedBox.square(
                dimension: CompressBeforeAfter.side,
                child: image == null
                    ? const DkSkeleton.page()
                    : ColoredBox(
                        color: t.color.pageWhite,
                        child: FittedBox(
                          fit: BoxFit.none,
                          alignment: CompressBeforeAfter.origin,
                          child: RawImage(image: image),
                        ),
                      ),
              ),
            ),
          ),
        ),
        Text(
          l.compress_zoom,
          textAlign: TextAlign.center,
          style: t.text.caption.copyWith(color: t.color.textSecondary),
        ),
      ],
    );
  }
}
