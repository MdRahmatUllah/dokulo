import 'package:flutter/material.dart';

import '../theme/dk_tokens.dart';
import 'dk_icon.dart';
import 'dk_number_text.dart';
import 'motion/dk_success_tick.dart';

/// A tool's result (DK-0090; UI spec §11.2, §21) on T3: a
/// `color.successContainer` card (`radius.m`, 16 padding; the warning tint
/// with [partial]) with the success tick (32), the [headline] number in
/// `type.numberXL` ("1.9 MB") and its [delta] ("(−77 %)", `type.titleM`
/// `color.success`), and the [sub] line in `type.bodyM` ("From 8.4 MB · 12
/// pages"). With [countFrom] / [countTo] / [format] the number counts up
/// after the tick (§9). [toggle] is the Before · After segmented control
/// (Compress, Watermark, Crop, Black out); [preview] the 64 dp thumbnail
/// strip under the card.
class DkResultCard extends StatelessWidget {
  const DkResultCard({
    super.key,
    required this.headline,
    required this.sub,
    this.delta,
    this.partial = false,
    this.countFrom,
    this.countTo,
    this.format,
    this.toggle,
    this.preview,
  });

  /// Always a number ("1.9 MB", "38 pages", "3 files").
  final String headline;
  final String? delta;
  final String sub;

  /// Some pages or files didn't make it: warning colours and icon.
  final bool partial;

  /// Count the headline up from [countFrom] to [countTo], shown through
  /// [format]; [headline] is what screen readers hear.
  final double? countFrom, countTo;
  final String Function(double value)? format;
  final Widget? toggle;
  final Widget? preview;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final tone = partial ? c.warning : c.success;
    final number = t.text.numberXL.copyWith(color: c.textPrimary);
    final counting = countFrom != null && countTo != null && format != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: t.space.m,
      children: [
        Container(
          padding: EdgeInsets.all(t.space.l),
          decoration: BoxDecoration(
            color: partial ? c.warningContainer : c.successContainer,
            borderRadius: BorderRadius.circular(t.radius.m),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: t.space.s,
            children: [
              if (partial)
                Icon(DkIcons.warning, size: 32, color: tone)
              else
                const DkSuccessTick(),
              Semantics(
                label: [headline, ?delta].join(' '),
                excludeSemantics: true,
                child: Wrap(
                  spacing: t.space.s,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    if (counting)
                      DkCountUp(
                        from: countFrom!,
                        to: countTo!,
                        format: format!,
                        style: number,
                      )
                    else
                      DkNumberText(headline, style: number),
                    if (delta != null)
                      DkNumberText(
                        delta!,
                        style: t.text.titleM.copyWith(color: tone),
                      ),
                  ],
                ),
              ),
              Text(sub, style: t.text.bodyM.copyWith(color: c.textPrimary)),
              ?toggle,
            ],
          ),
        ),
        if (preview != null) SizedBox(height: 64, child: preview),
      ],
    );
  }
}
