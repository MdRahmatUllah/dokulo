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

  /// The crop's side.
  static const side = 200.0;

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
    // Both, from the start: toggling doesn't render again, and Before
    // stays the original even after Replace original writes over it.
    final before = ref.watch(pdfCloseLookProvider(widget.before));
    final after = ref.watch(pdfCloseLookProvider(widget.after));
    // A page that can't be rendered (locked, gone): no comparison.
    if (before.hasError || after.hasError) return const SizedBox.shrink();
    final image = (_after ? after : before).value;
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
                        child: RawImage(image: image, fit: BoxFit.none),
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
