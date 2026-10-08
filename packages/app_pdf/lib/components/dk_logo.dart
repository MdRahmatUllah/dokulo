import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/dk_tokens.dart';

/// The Dokulo brand (DK-0070; UI spec §3, §31): the symbol (a page with a
/// folded corner and a small house: "Doku" + "lo(cal)"), the wordmark
/// "Dokulo" and the horizontal lockup. In `color.primary` by default; any
/// [color] makes it monochrome (white on primary, the notification glyph).
///
/// Each keeps its clear space, the height of the fold (12/64 of the
/// symbol), around itself. The symbol switches to its heavier small cut,
/// without the fold line, at 24 dp and below so it still reads at 16.
///
/// Sizes in use: launch screen 72, app lock 56, Me footer 24, About header
/// (the wordmark at 32), the app-switcher privacy cover.
class DkLogo extends StatelessWidget {
  /// The symbol, [size] dp square.
  const DkLogo.symbol({super.key, this.size = 72, this.color})
    : _kind = _Kind.symbol;

  /// The wordmark, its letters [size] dp tall (the font size).
  const DkLogo.wordmark({super.key, this.size = 32, this.color})
    : _kind = _Kind.wordmark;

  /// The symbol ([size] dp) with the wordmark beside it.
  const DkLogo.lockup({super.key, this.size = 48, this.color})
    : _kind = _Kind.lockup;

  final double size;
  final Color? color;
  final _Kind _kind;

  /// The brand's name, never translated or restyled ("Dokulo").
  static const name = 'Dokulo'; // l10n-ignore

  /// The clear space around a symbol of [size]: the fold's height.
  static double clearSpace(double size) => size * 12 / 64;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ink = color ?? t.color.primary;
    Widget symbol(double s) => SvgPicture.asset(
      s <= 24
          ? 'assets/brand/dokulo_symbol_small.svg'
          : 'assets/brand/dokulo_symbol.svg',
      width: s,
      height: s,
      colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
    );
    // The export's wordmark: 650 weight, −1 % tracking.
    Text wordmark(double fontSize) => Text(
      name,
      maxLines: 1,
      softWrap: false,
      textScaler: TextScaler.noScaling, // a logo, not text to read
      style: TextStyle(
        fontSize: fontSize,
        height: 1.2,
        fontWeight: FontWeight.w600,
        fontVariations: const [FontVariation('wght', 650)],
        letterSpacing: -0.01 * fontSize,
        color: color ?? t.color.textPrimary,
      ),
    );
    final (Widget art, double space) = switch (_kind) {
      _Kind.symbol => (symbol(size), clearSpace(size)),
      _Kind.wordmark => (wordmark(size), clearSpace(size)),
      _Kind.lockup => (
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: size / 4,
          children: [symbol(size), wordmark(size * 0.75)],
        ),
        clearSpace(size),
      ),
    };
    return Semantics(
      label: name,
      image: true,
      excludeSemantics: true,
      child: Padding(padding: EdgeInsets.all(space), child: art),
    );
  }
}

enum _Kind { symbol, wordmark, lockup }
