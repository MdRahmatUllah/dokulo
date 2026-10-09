import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/dk_camera_top_bar.dart';
import '../../components/dk_count_badge.dart';
import '../../components/dk_hint_pill.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_scan_button.dart';
import '../../components/dk_shutter_button.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/dk_tokens.dart';
import 'scan_hints.dart';
import 'scan_session.dart';
import 'scanner_settings.dart';
import 'scanner_camera.dart';

/// S1, the scanner's camera (DK-0343; UI spec S1, design
/// `10-scanner/scanner-camera-quad`, `-nodoc`, `-quad-iphone-se`):
///
/// - the full-bleed preview, letterboxed in black; all chrome on
///   `color.cameraChrome`, the same in both themes;
/// - DkCameraTopBar (close, flash, Auto, grid, settings) and DkHintPill 16
///   below it ("Ready" with a document, "Point at a document" without);
/// - the detected quad: `quadFill` and a 2 dp `quadStroke`, 12 dp corners;
///   the grid's thirds in white at 30 %;
/// - the mode switcher (Document · ID card · Book · Batch), then the 120 dp
///   bottom row: Import, DkShutterButton, the page stack (the last page
///   48 × 60 with a 2 dp white border and its count) to S2;
/// - a haptic tick on capture; in landscape the controls move to the right
///   edge.
///
/// The quad comes from [quadDetectorProvider], one frame at a time.
class S1Screen extends ConsumerStatefulWidget {
  const S1Screen({
    super.key,
    required this.onClose,
    required this.onImport,
    required this.onReview,
    required this.onSettings,
    this.initialMode,
    this.retake,
    this.onRetaken,
  });

  final VoidCallback onClose, onImport, onReview, onSettings;
  final DkScanMode? initialMode;

  /// Retake (DK-0350; opened from S2): the 0-based page this capture
  /// replaces. The hint says "Retake page 3" and [onRetaken] follows the
  /// shot.
  final int? retake;
  final VoidCallback? onRetaken;

  @override
  ConsumerState<S1Screen> createState() => _S1ScreenState();
}

class _S1ScreenState extends ConsumerState<S1Screen>
    with TickerProviderStateMixin {
  late final ScannerCamera _camera = ref.read(scannerCameraProvider);
  StreamSubscription<GreyFrame>? _frames;
  var _open = false;
  var _detecting = false;
  var _capturing = false;
  DetectedQuad? _quad;
  var _brightness = 1.0;
  var _steady = false;
  var _flash = DkFlash.off;
  // Auto-capture (DK-0338): when the quad has held still, a countdown on
  // the shutter's arc, then the shot.
  Duration? _steadySince;
  var _countdown = 0.0;
  static const _steadyFor = Duration(milliseconds: 500);
  var _grid = false;
  var _flashMenu = false;
  final _clock = Stopwatch()..start();
  late final HintAnnouncer _announcer = HintAnnouncer(_speak);

  // Capture feedback (DK-0349): an 80 ms white flash, the page flying to
  // the stack in 320 ms, the count popping.
  late final _flashFx = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 80),
  );
  late final _fly = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  Uint8List? _flying;
  final _stackKey = GlobalKey();

  void _speak(String text) {
    if (!mounted) return;
    SemanticsService.sendAnnouncement(
      View.of(context),
      text,
      Directionality.of(context),
    );
  }

  /// Auto-capture is on: the user's choice, or forced by Batch.
  bool get _autoActive =>
      ref.read(scanModeStateProvider) == DkScanMode.batch ||
      ref.read(scannerSettingsProvider).autoCapture;

  @override
  void initState() {
    super.initState();
    ref.read(scannerSettingsProvider.notifier).load();
    if (widget.initialMode case final m? when m != DkScanMode.importPhotos) {
      Future.microtask(() => ref.read(scanModeStateProvider.notifier).set(m));
    }
    _start();
  }

  Future<void> _start() async {
    try {
      await _camera.open();
    } on CameraUnavailable {
      if (mounted) widget.onClose();
      return;
    }
    if (!mounted) return;
    final detect = ref.read(quadDetectorProvider);
    _frames = _camera.frames.listen((frame) async {
      // One frame at a time: the next is taken when this one is done.
      if (_detecting) return;
      _detecting = true;
      try {
        final quad = await detect(frame);
        if (!mounted) return;
        setState(() {
          _steady = quadSteady(_quad, quad);
          _quad = quad;
          _brightness = brightnessOf(frame.bytes);
          final ready =
              scanHint(quad: quad, brightness: _brightness, steady: _steady) ==
              ScanHint.ready;
          if (_autoActive && ready) {
            _steadySince ??= frame.time;
            _countdown =
                ((frame.time - _steadySince!).inMicroseconds /
                        _steadyFor.inMicroseconds)
                    .clamp(0.0, 1.0);
          } else {
            _steadySince = null;
            _countdown = 0;
          }
        });
        if (_countdown >= 1) {
          _steadySince = null;
          _countdown = 0;
          await _capture();
        }
      } finally {
        _detecting = false;
      }
    });
    setState(() => _open = true);
  }

  @override
  void dispose() {
    _frames?.cancel();
    _camera.close();
    _flashFx.dispose();
    _fly.dispose();
    _pop.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_capturing || !_open) return;
    _capturing = true;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final l = AppLocalizations.of(context);
    try {
      HapticFeedback.lightImpact();
      if (!reduce) _flashFx.forward(from: 0).then((_) => _flashFx.reverse());
      final jpeg = await _camera.capture();
      if (!mounted) return;
      final session = ref.read(scanSessionProvider.notifier);
      if (widget.retake case final i?) {
        // Retake (DK-0350): the page is replaced and S2 comes back.
        await session.replace(i, jpeg, quad: _quad);
        widget.onRetaken?.call();
        return;
      }
      await session.add(jpeg, quad: _quad);
      if (!mounted) return;
      _speak(l.camera_page_captured(ref.read(scanSessionProvider).length));
      if (!reduce) {
        setState(() => _flying = jpeg);
        await _fly.forward(from: 0);
        if (mounted) setState(() => _flying = null);
        _pop.forward(from: 0);
      }
    } on CameraUnavailable {
      // ponytail: a failed shot is just not added; the camera stays open.
    } finally {
      _capturing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final pages = ref.watch(scanSessionProvider);
    final mode = ref.watch(scanModeStateProvider);
    final c = t.color;

    final preview = _Preview(
      camera: _open ? _camera : null,
      quad: _quad,
      grid: _grid,
    );
    final top = DkCameraTopBar(
      onClose: widget.onClose,
      flash: _flash,
      onFlash: (f) {
        setState(() => _flash = f);
        _camera.setFlash(f);
      },
      autoCapture:
          mode == DkScanMode.batch ||
          ref.watch(scannerSettingsProvider).autoCapture,
      onAutoCapture: (v) =>
          ref.read(scannerSettingsProvider.notifier).setAutoCapture(v),
      autoLocked: mode == DkScanMode.batch,
      grid: _grid,
      onGrid: (v) => setState(() => _grid = v),
      onSettings: widget.onSettings,
      onFlashMenu: () => setState(() => _flashMenu = true),
    );
    final hintKind = scanHint(
      quad: _quad,
      brightness: _brightness,
      steady: _steady,
      capturing: _countdown > 0,
    );
    _announcer.update(hintKind, hintKind.text(l), _clock.elapsed);
    final hint = DkHintPill(
      widget.retake == null
          ? hintKind.text(l)
          : l.camera_retake_page(widget.retake! + 1),
    );
    final modes = _ModeSwitcher(
      mode: mode,
      onMode: (m) => ref.read(scanModeStateProvider.notifier).set(m),
    );
    final importButton = Semantics(
      button: true,
      label: l.scan_import_photos,
      excludeSemantics: true,
      onTap: widget.onImport,
      child: InkResponse(
        onTap: widget.onImport,
        radius: 28,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.onCamera.withValues(alpha: 0.16),
          ),
          child: Center(
            child: DkIcon(
              DkIcons.importPhotos,
              size: DkIconSize.xl,
              color: c.onCamera,
            ),
          ),
        ),
      ),
    );
    final shutter = DkShutterButton(
      onPressed: _open ? _capture : null,
      countdown: _countdown,
    );
    final stack = ScaleTransition(
      key: _stackKey,
      // The count pops when the page lands.
      scale: TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 1),
        TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0), weight: 1),
      ]).animate(_pop),
      child: _PageStack(
        pages: pages,
        image: pages.isEmpty
            ? null
            : ref.read(scanStoreProvider).image(pages.last.path),
        onTap: pages.isEmpty ? null : widget.onReview,
      ),
    );

    return Material(
      // The camera's black around the preview, in both themes.
      color: c.cameraChrome.withValues(alpha: 1),
      child: Stack(
        children: [
          Positioned.fill(
            child: OrientationBuilder(
              builder: (context, orientation) {
                if (orientation == Orientation.landscape) {
                  // Phone landscape: the controls along the right edge.
                  return Row(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(child: preview),
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: SafeArea(
                                bottom: false,
                                right: false,
                                child: top,
                              ),
                            ),
                            Positioned(
                              top: 72,
                              left: 0,
                              right: 0,
                              child: SafeArea(child: Center(child: hint)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 120,
                        color: c.cameraChrome,
                        child: SafeArea(
                          left: false,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              stack,
                              shutter,
                              importButton,
                              Flexible(
                                child: _ModeSwitcher(
                                  mode: mode,
                                  onMode: (m) => ref
                                      .read(scanModeStateProvider.notifier)
                                      .set(m),
                                  axis: Axis.vertical,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return Stack(
                  children: [
                    Positioned.fill(child: preview),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: c.cameraChrome,
                        child: SafeArea(bottom: false, child: top),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        child: Padding(
                          padding: EdgeInsets.only(top: 56 + t.space.l),
                          child: Center(child: hint),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: c.cameraChrome,
                        child: SafeArea(
                          top: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(height: 44, child: modes),
                              SizedBox(
                                height: 120,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    28,
                                    0,
                                    28,
                                    24,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [importButton, shutter, stack],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // The capture flash: white, 80 ms in and out.
          IgnorePointer(
            child: FadeTransition(
              opacity: _flashFx,
              child: ColoredBox(
                color: c.onCamera,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          if (_flying case final jpeg?) _flyingPage(jpeg),
          if (_flashMenu) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _flashMenu = false),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 56,
              right: 96,
              child: _FlashMenu(
                flash: _flash,
                onPick: (f) {
                  setState(() {
                    _flash = f;
                    _flashMenu = false;
                  });
                  _camera.setFlash(f);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The captured page flying from the middle of the screen to the stack.
  Widget _flyingPage(Uint8List jpeg) {
    final size = MediaQuery.sizeOf(context);
    final from = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * 0.6,
      height: size.width * 0.75,
    );
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final to = box == null ? from : box.localToGlobal(Offset.zero) & box.size;
    return AnimatedBuilder(
      animation: _fly,
      builder: (context, _) {
        final r = Rect.lerp(
          from,
          to,
          Curves.easeInOutCubic.transform(_fly.value),
        )!;
        return Positioned.fromRect(
          rect: r,
          child: IgnorePointer(
            child: Image.memory(jpeg, fit: BoxFit.cover, gaplessPlayback: true),
          ),
        );
      },
    );
  }
}

/// The flash menu (DK-0345; design `scanner-camera-flash`): Off, On, Auto on
/// a dark panel (#14171C at 92 %, radius 12), a check by the current one.
class _FlashMenu extends StatelessWidget {
  const _FlashMenu({required this.flash, required this.onPick});

  final DkFlash flash;
  final ValueChanged<DkFlash> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final on = t.color.onCamera;
    return Semantics(
      container: true,
      label: l.camera_flash_menu,
      explicitChildNodes: true,
      // As wide as its longest row, at least 150.
      child: IntrinsicWidth(
        child: Container(
          constraints: const BoxConstraints(minWidth: 150),
          padding: EdgeInsets.symmetric(vertical: t.space.xs),
          decoration: BoxDecoration(
            // The export's panel: the light ink, 92 %, in both themes.
            color: DkColors.light.textPrimary.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(t.radius.m),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (f, icon, label) in [
                (DkFlash.off, DkIcons.flashOff, l.camera_flash_off),
                (DkFlash.on, DkIcons.flashOn, l.camera_flash_on),
                (DkFlash.auto, DkIcons.flashAuto, l.camera_flash_auto),
              ])
                Semantics(
                  button: true,
                  selected: f == flash,
                  inMutuallyExclusiveGroup: true,
                  label: label,
                  excludeSemantics: true,
                  onTap: () => onPick(f),
                  child: InkWell(
                    onTap: () => onPick(f),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: t.space.l),
                        child: Row(
                          spacing: t.space.m,
                          children: [
                            DkIcon(icon, color: on),
                            Expanded(
                              child: Text(
                                label,
                                style: t.text.bodyL.copyWith(color: on),
                              ),
                            ),
                            if (f == flash)
                              DkIcon(
                                DkIcons.check,
                                color: DkColors.dark.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The preview, letterboxed, with the quad and the grid over it.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.camera,
    required this.quad,
    required this.grid,
  });

  final ScannerCamera? camera;
  final DetectedQuad? quad;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.color;
    final cam = camera;
    final ratio = cam?.aspectRatio ?? 3 / 4;
    return Center(
      child: AspectRatio(
        aspectRatio: ratio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cam != null) cam.preview(),
            CustomPaint(
              painter: _QuadPainter(
                quad: quad,
                grid: grid,
                fill: c.quadFill,
                stroke: c.quadStroke,
                lines: c.onCamera.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuadPainter extends CustomPainter {
  const _QuadPainter({
    required this.quad,
    required this.grid,
    required this.fill,
    required this.stroke,
    required this.lines,
  });

  final DetectedQuad? quad;
  final bool grid;
  final Color fill, stroke, lines;

  @override
  void paint(Canvas canvas, Size size) {
    if (grid) {
      final p = Paint()
        ..color = lines
        ..strokeWidth = 1;
      for (final f in [1 / 3, 2 / 3]) {
        canvas.drawLine(
          Offset(size.width * f, 0),
          Offset(size.width * f, size.height),
          p,
        );
        canvas.drawLine(
          Offset(0, size.height * f),
          Offset(size.width, size.height * f),
          p,
        );
      }
    }
    final q = quad;
    if (q == null || q.length != 4) return;
    final pts = [
      for (final o in q) Offset(o.dx * size.width, o.dy * size.height),
    ];
    final path = _rounded(pts, 12);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// The quad with its corners rounded by [r].
  static Path _rounded(List<Offset> p, double r) {
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final prev = p[(i + 3) % 4], cur = p[i], next = p[(i + 1) % 4];
      Offset toward(Offset from, Offset to) {
        final d = to - from;
        final len = d.distance;
        return len == 0 ? from : from + d / len * (r < len / 2 ? r : len / 2);
      }

      final a = toward(cur, prev), b = toward(cur, next);
      if (i == 0) {
        path.moveTo(a.dx, a.dy);
      } else {
        path.lineTo(a.dx, a.dy);
      }
      path.quadraticBezierTo(cur.dx, cur.dy, b.dx, b.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_QuadPainter old) => old.quad != quad || old.grid != grid;
}

/// Document · ID card · Book · Batch: the selected one white with a dot,
/// the others white at 60 %.
class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({
    required this.mode,
    required this.onMode,
    this.axis = Axis.horizontal,
  });

  final DkScanMode mode;
  final ValueChanged<DkScanMode> onMode;

  /// Vertical along the right edge in landscape.
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: axis,
      child: Flex(
        direction: axis,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in DkScanMode.values)
            if (m != DkScanMode.importPhotos)
              Semantics(
                button: true,
                selected: m == mode,
                inMutuallyExclusiveGroup: true,
                label: m.label(l),
                excludeSemantics: true,
                onTap: () => onMode(m),
                child: InkWell(
                  onTap: () => onMode(m),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 44,
                      minWidth: 48,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: t.space.m),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            m.label(l),
                            style: t.text.labelL.copyWith(
                              color: t.color.onCamera.withValues(
                                alpha: m == mode ? 1 : 0.6,
                              ),
                            ),
                          ),
                          SizedBox(height: t.space.xxs),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: m == mode ? t.color.onCamera : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// The last page captured (48 × 60, a 2 dp white border) with the count: to
/// S2. Empty until the first capture.
class _PageStack extends StatelessWidget {
  const _PageStack({
    required this.pages,
    required this.image,
    required this.onTap,
  });

  final List<ScannedPage> pages;

  /// The last page's photo.
  final ImageProvider? image;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    if (pages.isEmpty) return const SizedBox(width: 48, height: 60);
    return Semantics(
      button: true,
      label: l.camera_review(pages.length),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 60,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: t.color.onCamera, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: RotatedBox(
                    quarterTurns: pages.last.turns,
                    child: Image(
                      image: image!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
              Positioned(top: -8, right: -8, child: DkCountBadge(pages.length)),
            ],
          ),
        ),
      ),
    );
  }
}
