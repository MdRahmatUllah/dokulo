import 'package:flutter/material.dart';

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
    // Painted, not an SVG asset: an asset decodes after the first frame, and
    // the launch screen's first frame must already show it (DK-0073).
    Widget symbol(double s) => CustomPaint(
      size: Size.square(s),
      painter: DkSymbolPainter(ink, small: s <= 24),
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

/// The Dokulo symbol on a 64 unit grid (docs/design/brand/dokulo_symbol.svg):
/// the page with its folded corner, stroked 4, and the house, filled. The
/// [small] cut (24 dp and below) strokes 6 and leaves out the fold line.
class DkSymbolPainter extends CustomPainter {
  const DkSymbolPainter(this.color, {this.small = false});

  final Color color;
  final bool small;

  static final _page = Path()
    ..moveTo(18, 8)
    ..lineTo(38, 8)
    ..lineTo(50, 20)
    ..lineTo(50, 52)
    ..arcToPoint(const Offset(46, 56), radius: const Radius.circular(4))
    ..lineTo(18, 56)
    ..arcToPoint(const Offset(14, 52), radius: const Radius.circular(4))
    ..lineTo(14, 12)
    ..arcToPoint(const Offset(18, 8), radius: const Radius.circular(4))
    ..close();
  static final _fold = Path()
    ..moveTo(38, 8)
    ..lineTo(38, 16)
    ..arcToPoint(
      const Offset(42, 20),
      radius: const Radius.circular(4),
      clockwise: false,
    )
    ..lineTo(50, 20);
  static final _house = Path()
    ..moveTo(23, 45)
    ..lineTo(32, 37)
    ..lineTo(41, 45)
    ..lineTo(41, 50)
    ..lineTo(23, 50)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64, size.height / 64);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = small ? 6 : 4
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(_page, stroke);
    if (!small) canvas.drawPath(_fold, stroke);
    canvas.drawPath(_house, Paint()..color = color);
  }

  @override
  bool shouldRepaint(DkSymbolPainter old) =>
      old.color != color || old.small != small;
}
