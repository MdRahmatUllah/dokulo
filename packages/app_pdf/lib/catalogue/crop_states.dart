import 'package:flutter/material.dart';

import '../components/dk_crop_overlay.dart';
import '../theme/dk_tokens.dart';
import 'page_states.dart';

/// DkCropOverlay (DK-0156): a photographed page with a tilted quad that
/// snaps to the detected corners; then rectangle mode (Crop pages). Live:
/// drag the handles; Auto, Full page and Reset work.
class CropStates extends StatefulWidget {
  const CropStates({super.key});

  static const detected = [
    Offset(0.14, 0.10),
    Offset(0.86, 0.08),
    Offset(0.90, 0.90),
    Offset(0.10, 0.92),
  ];
  static const full = [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)];
  static const margins = [
    Offset(0.08, 0.06),
    Offset(0.92, 0.06),
    Offset(0.92, 0.94),
    Offset(0.08, 0.94),
  ];

  @override
  State<CropStates> createState() => _CropStatesState();
}

class _CropStatesState extends State<CropStates> {
  var quad = CropStates.detected;
  var rect = CropStates.margins;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // A page photographed on a dark table (the export's colours).
    final photo = ColoredBox(
      color: const Color(0xFF3A3631),
      child: ClipPath(
        clipper: _Quad(CropStates.detected),
        child: const ColoredBox(
          color: Color(0xFFF2F0EA),
          child: FittedBox(child: CataloguePage()),
        ),
      ),
    );
    return ColoredBox(
      color: t.color.surfaceSunken,
      child: Padding(
        padding: EdgeInsets.all(t.space.l),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: t.space.l,
          children: [
            Expanded(
              child: DkCropOverlay(
                image: photo,
                aspectRatio: 3 / 4,
                quad: quad,
                snapTo: CropStates.detected,
                onChanged: (q) => setState(() => quad = q),
                onAuto: () => setState(() => quad = CropStates.detected),
                onFullPage: () => setState(() => quad = CropStates.full),
                onReset: () => setState(() => quad = CropStates.detected),
              ),
            ),
            Expanded(
              child: DkCropOverlay(
                image: const ColoredBox(
                  color: Color(0xFFFFFFFF),
                  child: FittedBox(child: CataloguePage()),
                ),
                aspectRatio: 3 / 4,
                quad: rect,
                rectangle: true,
                onChanged: (q) => setState(() => rect = q),
                onAuto: () => setState(() => rect = CropStates.margins),
                onReset: () => setState(() => rect = CropStates.margins),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Quad extends CustomClipper<Path> {
  const _Quad(this.quad);
  final List<Offset> quad;

  @override
  Path getClip(Size size) => Path()
    ..addPolygon([
      for (final q in quad) Offset(q.dx * size.width, q.dy * size.height),
    ], true);

  @override
  bool shouldReclip(_Quad old) => false;
}
