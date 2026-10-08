import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/dk_tokens.dart';
import 'dk_color_row.dart';
import 'dk_segmented.dart';
import 'dk_slider.dart';
import 'dk_stepper.dart';

/// The markup tools that have options.
enum DkMarkupKind { pen, highlighter, text, shape, eraser }

/// What a shape tool draws.
enum DkShapeKind { rectangle, ellipse, line, arrow }

/// What the eraser takes: a whole object, or the stroke under the finger.
enum DkEraserMode { object, stroke }

/// A markup tool's settings.
@immutable
class DkToolOptions {
  const DkToolOptions({
    required this.color,
    this.thickness = 3,
    this.opacity = 0.4,
    this.fontSize = 14,
    this.shape = DkShapeKind.rectangle,
    this.eraser = DkEraserMode.object,
  });

  final Color color;

  /// The stroke, in points (1–12).
  final double thickness;

  /// The highlighter's, 30–60 % (UI spec §17.2).
  final double opacity;

  /// Text, in points.
  final int fontSize;
  final DkShapeKind shape;
  final DkEraserMode eraser;

  DkToolOptions copyWith({
    Color? color,
    double? thickness,
    double? opacity,
    int? fontSize,
    DkShapeKind? shape,
    DkEraserMode? eraser,
  }) => DkToolOptions(
    color: color ?? this.color,
    thickness: thickness ?? this.thickness,
    opacity: opacity ?? this.opacity,
    fontSize: fontSize ?? this.fontSize,
    shape: shape ?? this.shape,
    eraser: eraser ?? this.eraser,
  );
}

/// The options of the selected markup tool (DK-0204; UI spec §11.8), the
/// body of a small `showDkSheet` titled with the tool's name: the markup
/// colours (DkColorRow), then what the tool has:
///
/// - **pen, shape:** the thickness slider with a live 120 × 24 stroke;
/// - **highlighter:** the thickness, and the opacity slider;
/// - **text:** the font size stepper;
/// - **shape:** Rectangle · Ellipse · Line · Arrow;
/// - **eraser:** Object · Stroke (no colours).
///
/// Every change is applied at once ([onChanged]); closing the sheet keeps it.
class DkToolOptionsSheet extends StatelessWidget {
  const DkToolOptionsSheet({
    super.key,
    required this.kind,
    required this.options,
    required this.onChanged,
  });

  final DkMarkupKind kind;
  final DkToolOptions options;
  final ValueChanged<DkToolOptions> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final o = options;
    final stroke = switch (kind) {
      DkMarkupKind.pen ||
      DkMarkupKind.highlighter ||
      DkMarkupKind.shape => true,
      _ => false,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: t.space.l,
      children: [
        if (kind != DkMarkupKind.eraser)
          DkColorRow(
            // UI spec §17.2: the highlighter has its four colours and no
            // custom; the pen black, blue ink and red, plus custom.
            swatches: switch (kind) {
              DkMarkupKind.highlighter => markupSwatches(t, l).take(4).toList(),
              DkMarkupKind.pen => [
                (color: t.markup.black, name: l.colour_black),
                (color: t.markup.ink, name: l.markup_ink),
                (color: t.markup.red, name: l.colour_red),
              ],
              _ => markupSwatches(t, l),
            },
            custom: kind != DkMarkupKind.highlighter,
            selected: o.color,
            onChanged: (c) => onChanged(o.copyWith(color: c)),
          ),
        if (stroke) ...[
          DkSlider(
            title: l.options_thickness,
            value: o.thickness,
            min: 1,
            // The pen 1–8 pt (UI spec §17.2); shapes and the highlighter 1–12.
            max: kind == DkMarkupKind.pen ? 8 : 12,
            divisions: kind == DkMarkupKind.pen ? 7 : 11,
            format: (v) => l.options_points(v.round()),
            onChanged: (v) => onChanged(o.copyWith(thickness: v)),
          ),
          Center(
            child: DkStrokePreview(
              color: o.color,
              thickness: o.thickness,
              opacity: kind == DkMarkupKind.highlighter ? o.opacity : 1,
            ),
          ),
        ],
        if (kind == DkMarkupKind.highlighter)
          DkSlider(
            title: l.options_opacity,
            value: o.opacity,
            min: 0.3,
            max: 0.6,
            divisions: 3,
            format: (v) => '${(v * 100).round()} %',
            onChanged: (v) => onChanged(o.copyWith(opacity: v)),
          ),
        if (kind == DkMarkupKind.text)
          Row(
            children: [
              Expanded(
                child: Text(
                  l.options_font_size,
                  style: t.text.titleS.copyWith(color: t.color.textPrimary),
                ),
              ),
              DkStepper(
                label: l.options_font_size,
                value: o.fontSize,
                min: 8, // 8–24 pt (UI spec §17.2)
                max: 24,
                onChanged: (v) => onChanged(o.copyWith(fontSize: v)),
              ),
            ],
          ),
        if (kind == DkMarkupKind.shape)
          DkSegmented<DkShapeKind>(
            segments: [
              (DkShapeKind.rectangle, l.options_shape_rectangle),
              (DkShapeKind.ellipse, l.options_shape_ellipse),
              (DkShapeKind.line, l.options_shape_line),
              (DkShapeKind.arrow, l.options_shape_arrow),
            ],
            selected: o.shape,
            onChanged: (v) => onChanged(o.copyWith(shape: v)),
          ),
        if (kind == DkMarkupKind.eraser)
          DkSegmented<DkEraserMode>(
            segments: [
              (DkEraserMode.object, l.options_eraser_object),
              (DkEraserMode.stroke, l.options_eraser_stroke),
            ],
            selected: o.eraser,
            onChanged: (v) => onChanged(o.copyWith(eraser: v)),
          ),
      ],
    );
  }
}

/// A 120 × 24 sample of the stroke as it will be drawn: a gentle wave in
/// [color] at [thickness] (points as dp) and [opacity]. Decorative: the
/// slider says the value.
class DkStrokePreview extends StatelessWidget {
  const DkStrokePreview({
    super.key,
    required this.color,
    required this.thickness,
    this.opacity = 1,
  });

  final Color color;
  final double thickness, opacity;

  static const size = Size(120, 24);

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: size,
      painter: _Wave(color.withValues(alpha: opacity), thickness),
    ),
  );
}

class _Wave extends CustomPainter {
  _Wave(this.color, this.width);
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final amp = math.max(0.0, mid - width / 2 - 1);
    final path = Path()..moveTo(width / 2, mid);
    for (var x = width / 2; x <= size.width - width / 2; x += 2) {
      path.lineTo(x, mid + amp * math.sin(x / size.width * 2 * math.pi));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_Wave old) => old.color != color || old.width != width;
}
