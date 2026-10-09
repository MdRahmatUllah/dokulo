import 'dart:math' as math;
import 'dart:typed_data';

import '../../l10n/app_localizations.dart';
import 'scan_session.dart';

/// The hint pill's messages (DK-0344), in priority order: the first that
/// applies is shown.
enum ScanHint {
  pointAt,
  moveCloser,
  holdSteady,
  moreLight,
  fitPage,
  ready,
  capturing;

  String text(AppLocalizations l) => switch (this) {
    pointAt => l.camera_hint_point,
    moveCloser => l.camera_hint_closer,
    holdSteady => l.camera_hint_steady,
    moreLight => l.camera_hint_light,
    fitPage => l.camera_hint_fit,
    ready => l.camera_hint_ready,
    capturing => l.camera_hint_capturing,
  };
}

/// A page smaller than this share of the frame is "too far".
const minPageShare = 0.2;

/// A frame darker than this mean luminance (0–1) needs more light.
const minBrightness = 0.22;

/// A corner closer than this to the frame's edge means the page is cut off.
const edgeMargin = 0.02;

/// The hint for what the camera sees now: [quad] (or none), the frame's
/// [brightness] (0–1), whether the quad held [steady], and whether
/// auto-capture is counting down ([capturing]).
ScanHint scanHint({
  required DetectedQuad? quad,
  required double brightness,
  required bool steady,
  bool capturing = false,
}) {
  if (quad == null || quad.length != 4) return ScanHint.pointAt;
  if (quadArea(quad) < minPageShare) return ScanHint.moveCloser;
  if (!steady) return ScanHint.holdSteady;
  if (brightness < minBrightness) return ScanHint.moreLight;
  if (quad.any(
    (p) =>
        p.dx < edgeMargin ||
        p.dy < edgeMargin ||
        p.dx > 1 - edgeMargin ||
        p.dy > 1 - edgeMargin,
  )) {
    return ScanHint.fitPage;
  }
  return capturing ? ScanHint.capturing : ScanHint.ready;
}

/// The quad's share of the frame (shoelace, on 0–1 coordinates).
double quadArea(DetectedQuad q) {
  var sum = 0.0;
  for (var i = 0; i < q.length; i++) {
    final a = q[i], b = q[(i + 1) % q.length];
    sum += a.dx * b.dy - b.dx * a.dy;
  }
  return sum.abs() / 2;
}

/// The mean luminance (0–1) of a Y plane, from every 64th byte: cheap enough
/// for every preview frame.
double brightnessOf(Uint8List y) {
  if (y.isEmpty) return 0;
  var sum = 0, n = 0;
  for (var i = 0; i < y.length; i += 64) {
    sum += y[i];
    n++;
  }
  return sum / n / 255;
}

/// Whether the quad held still between frames: no corner moved more than
/// [tolerance] of the frame.
bool quadSteady(
  DetectedQuad? before,
  DetectedQuad? now, {
  double tolerance = 0.02,
}) {
  if (before == null || now == null || before.length != now.length) {
    return false;
  }
  var worst = 0.0;
  for (var i = 0; i < now.length; i++) {
    worst = math.max(worst, (now[i] - before[i]).distance);
  }
  return worst <= tolerance;
}

/// Speaks hint changes to screen readers, at most every [gap] so a jittery
/// detector doesn't flood them (DK-0344: "announcements throttled").
class HintAnnouncer {
  HintAnnouncer(this.speak, {this.gap = const Duration(seconds: 2)});

  final void Function(String text) speak;
  final Duration gap;
  ScanHint? _last;
  Duration? _at;

  /// Feeds the current hint at [now]; speaks it when it changed and the last
  /// announcement was at least [gap] ago.
  void update(ScanHint hint, String text, Duration now) {
    if (hint == _last) return;
    if (_at != null && now - _at! < gap) return;
    _last = hint;
    _at = now;
    speak(text);
  }
}
