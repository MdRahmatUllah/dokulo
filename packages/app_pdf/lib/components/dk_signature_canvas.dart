import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';

/// One sampled point of a stroke: where, when (ms) and how wide.
typedef _Point = ({Offset at, double ms, double width});

/// The strokes of a signature being drawn (DK-0206), in the canvas's
/// coordinates. Listen to it to repaint; [toPng] exports it.
class DkSignatureController extends ChangeNotifier {
  /// Black by default; the pad's toggle switches to blue ink.
  DkSignatureController({Color? ink}) : _ink = ink ?? const DkMarkup().black;

  final _strokes = <List<_Point>>[];

  /// The pen's width range, in dp: thin when fast, full when slow (or by
  /// the stylus's pressure).
  static const minWidth = 1.2, maxWidth = 3.6;

  Color _ink;
  Color get ink => _ink;
  set ink(Color value) {
    if (value == _ink) return;
    _ink = value;
    notifyListeners();
  }

  bool get isEmpty => _strokes.isEmpty;

  /// The last stroke's widths, sample by sample.
  @visibleForTesting
  List<double> get lastWidths => [for (final p in _strokes.last) p.width];

  void clear() {
    _strokes.clear();
    notifyListeners();
  }

  /// A finger or a stylus touched down at [at] ([ms] from its timestamp).
  /// [pressure] 0–1 when the device reports one.
  void begin(Offset at, double ms, {double? pressure}) {
    _strokes.add([
      (at: at, ms: ms, width: _byPressure(pressure) ?? maxWidth * 0.8),
    ]);
    notifyListeners();
  }

  /// The pen moved on to [at].
  void extend(Offset at, double ms, {double? pressure}) {
    if (_strokes.isEmpty) return begin(at, ms, pressure: pressure);
    final stroke = _strokes.last;
    final last = stroke.last;
    final distance = (at - last.at).distance;
    if (distance < 0.5) return; // nothing new to draw
    final target =
        _byPressure(pressure) ??
        // Velocity in dp/ms: faster strokes are thinner, as with a pen.
        (maxWidth / (1 + 0.9 * distance / math.max(ms - last.ms, 1))).clamp(
          minWidth,
          maxWidth,
        );
    // Ease towards it, so the width never jumps between samples.
    final width = last.width * 0.6 + target * 0.4;
    stroke.add((at: at, ms: ms, width: width));
    notifyListeners();
  }

  static double? _byPressure(double? pressure) => pressure == null
      ? null
      : ui.lerpDouble(minWidth, maxWidth, pressure.clamp(0.0, 1.0));

  /// Paints the strokes: each segment a quadratic curve between the
  /// midpoints of its samples (the sample is the control point), with round
  /// caps so the joints stay smooth; a single tap is a dot.
  void paint(Canvas canvas) {
    final pen = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    for (final s in _strokes) {
      if (s.length == 1) {
        canvas.drawCircle(s.first.at, s.first.width / 2, Paint()..color = _ink);
        continue;
      }
      for (var i = 1; i < s.length; i++) {
        final from = i == 1
            ? s[0].at
            : Offset.lerp(s[i - 2].at, s[i - 1].at, .5)!;
        final control = s[i - 1].at;
        final to = Offset.lerp(s[i - 1].at, s[i].at, .5)!;
        final path = Path()
          ..moveTo(from.dx, from.dy)
          ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
        canvas.drawPath(path, pen..strokeWidth = s[i].width);
      }
      // The last half segment, to the finger's last point.
      final end = s.last.at;
      final mid = Offset.lerp(s[s.length - 2].at, end, .5)!;
      canvas.drawLine(mid, end, pen..strokeWidth = s.last.width);
    }
  }

  /// The signature as a PNG: transparent around the ink, trimmed to the
  /// strokes plus a pen's width, at [pixelRatio] pixels per dp. Null when
  /// nothing is drawn.
  Future<Uint8List?> toPng({double pixelRatio = 3}) async {
    if (isEmpty) return null;
    var bounds = Rect.fromPoints(
      _strokes.first.first.at,
      _strokes.first.first.at,
    );
    for (final s in _strokes) {
      for (final p in s) {
        bounds = bounds.expandToInclude(
          Rect.fromCircle(center: p.at, radius: 0),
        );
      }
    }
    bounds = bounds.inflate(maxWidth);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(pixelRatio)
      ..translate(-bounds.left, -bounds.top);
    paint(canvas);
    final image = await recorder.endRecording().toImage(
      (bounds.width * pixelRatio).ceil(),
      (bounds.height * pixelRatio).ceil(),
    );
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return png?.buffer.asUint8List();
  }
}

/// The signature pad's drawing area (DK-0206; UI spec §11.8): always
/// `color.pageWhite`, a 1 dp `color.outlineStrong` baseline at 70 % of the
/// height, and "Sign on the line" in `type.caption` until something is
/// drawn. A finger or stylus draws into [controller]; a stylus's pressure
/// sets the width, otherwise the speed does.
///
/// Screen readers can't draw: they hear the hint, and the pad's Type tab is
/// their way to sign.
class DkSignatureCanvas extends StatelessWidget {
  const DkSignatureCanvas({super.key, required this.controller});

  final DkSignatureController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hint = AppLocalizations.of(context).sign_pad_hint;
    double ms(PointerEvent e) => e.timeStamp.inMicroseconds / 1000;
    double? pressure(PointerEvent e) =>
        e.kind == PointerDeviceKind.stylus && e.pressureMax > e.pressureMin
        ? (e.pressure - e.pressureMin) / (e.pressureMax - e.pressureMin)
        : null;
    return Semantics(
      label: hint,
      image: true,
      excludeSemantics: true,
      child: ClipRect(
        child: ColoredBox(
          color: t.color.pageWhite,
          child: LayoutBuilder(
            builder: (context, box) {
              final baseline = box.maxHeight * 0.7;
              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) => controller.begin(
                  e.localPosition,
                  ms(e),
                  pressure: pressure(e),
                ),
                onPointerMove: (e) => controller.extend(
                  e.localPosition,
                  ms(e),
                  pressure: pressure(e),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: t.space.xl,
                      right: t.space.xl,
                      top: baseline,
                      height: 1,
                      child: ColoredBox(color: t.color.outlineStrong),
                    ),
                    ListenableBuilder(
                      listenable: controller,
                      builder: (context, _) => controller.isEmpty
                          ? Positioned(
                              left: t.space.xl,
                              right: t.space.xl,
                              top: baseline + t.space.s,
                              child: Text(
                                hint,
                                textAlign: TextAlign.center,
                                // On white in both themes: dark grey.
                                style: t.text.caption.copyWith(
                                  color: DkColors.light.textSecondary,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Positioned.fill(
                      child: CustomPaint(painter: _InkPainter(controller)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InkPainter extends CustomPainter {
  _InkPainter(this.controller) : super(repaint: controller);

  final DkSignatureController controller;

  @override
  void paint(Canvas canvas, Size size) => controller.paint(canvas);

  @override
  bool shouldRepaint(_InkPainter old) => old.controller != controller;
}
