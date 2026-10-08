import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/dk_tokens.dart';
import 'dk_button.dart';
import 'dk_icon.dart';
import 'dk_ring.dart';
import 'dk_segmented.dart';
import 'dk_signature_canvas.dart';
import 'dk_tappable.dart';
import 'dk_top_bar.dart';

/// How a signature is made.
enum DkSignatureMode { draw, type, image }

/// Adding a signature (DK-0206; UI spec §11.8, §17.3): a full-screen,
/// landscape page. The top bar has Cancel, "Add signature" and Save (off
/// until there is something to save). Under it, Draw · Type · Image.
///
/// - **Draw:** the [DkSignatureCanvas], the ink (Black or Blue ink) and
///   Clear at the bottom left.
/// - **Type:** the name, and three handwriting styles to choose from.
/// - **Image:** Take photo and Choose photo; the screen crops the photo and
///   removes the paper ([onTakePhoto], [onChoosePhoto]).
///
/// Save hands [onSave] the signature as a PNG: transparent around the ink
/// and trimmed to it. The canvas card is paper, white in both themes, so
/// what sits on it is drawn in the light theme.
class DkSignaturePad extends StatefulWidget {
  const DkSignaturePad({
    super.key,
    required this.onCancel,
    required this.onSave,
    this.onTakePhoto,
    this.onChoosePhoto,
    this.name = '',
    this.initialMode = DkSignatureMode.draw,
  });

  final VoidCallback onCancel;
  final ValueChanged<Uint8List> onSave;
  final VoidCallback? onTakePhoto, onChoosePhoto;

  /// The Type tab's name to start with (the user's, when known).
  final String name;
  final DkSignatureMode initialMode;

  /// The Type tab's styles, in the export's order (UI spec §17.3).
  static const fonts = ['HomemadeApple', 'Caveat', 'DancingScript'];

  @override
  State<DkSignaturePad> createState() => _DkSignaturePadState();
}

class _DkSignaturePadState extends State<DkSignaturePad> {
  late var _mode = widget.initialMode;
  final _drawing = DkSignatureController();
  late final _name = TextEditingController(text: widget.name);
  var _font = 0;

  @override
  void initState() {
    super.initState();
    // Save follows what there is to save.
    _drawing.addListener(_changed);
    _name.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _drawing.dispose();
    _name.dispose();
    super.dispose();
  }

  bool get _canSave => switch (_mode) {
    DkSignatureMode.draw => !_drawing.isEmpty,
    DkSignatureMode.type => _name.text.trim().isNotEmpty,
    DkSignatureMode.image => false, // the photo flow saves on its own
  };

  Future<void> _save() async {
    final png = _mode == DkSignatureMode.draw
        ? await _drawing.toPng()
        : await _typed(_name.text.trim(), DkSignaturePad.fonts[_font]);
    if (png != null && mounted) widget.onSave(png);
  }

  /// The typed name in [font] and blue ink, as a trimmed transparent PNG.
  Future<Uint8List?> _typed(String name, String font) async {
    const ratio = 3.0;
    final text = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          fontFamily: font,
          fontSize: 40,
          color: const DkMarkup().ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final recorder = ui.PictureRecorder();
    text.paint(Canvas(recorder)..scale(ratio), Offset.zero);
    final image = await recorder.endRecording().toImage(
      (text.width * ratio).ceil(),
      (text.height * ratio).ceil(),
    );
    text.dispose();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return png?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    return ColoredBox(
      color: t.color.background,
      child: Column(
        children: [
          DkTopBar.editing(
            title: l.sign_pad_title,
            onCancel: widget.onCancel,
            onDone: _canSave ? _save : null,
            doneLabel: l.common_save,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  t.space.xxl,
                  t.space.m,
                  t.space.xxl,
                  t.space.l,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: t.space.m,
                  children: [
                    Wrap(
                      spacing: t.space.l,
                      runSpacing: t.space.s,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 300,
                          child: DkSegmented<DkSignatureMode>(
                            segments: [
                              (DkSignatureMode.draw, l.sign_pad_draw),
                              (DkSignatureMode.type, l.sign_pad_type),
                              (DkSignatureMode.image, l.sign_pad_image),
                            ],
                            selected: _mode,
                            onChanged: (m) => setState(() => _mode = m),
                          ),
                        ),
                        if (_mode == DkSignatureMode.draw)
                          _InkPicker(
                            ink: _drawing.ink,
                            onChanged: (c) => _drawing.ink = c,
                          ),
                      ],
                    ),
                    Expanded(child: _Paper(child: _tab(context))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    return switch (_mode) {
      DkSignatureMode.draw => Stack(
        children: [
          Positioned.fill(child: DkSignatureCanvas(controller: _drawing)),
          Positioned(
            left: t.space.s,
            bottom: t.space.s,
            child: DkButton(
              label: l.sign_pad_clear,
              onPressed: _drawing.isEmpty ? null : _drawing.clear,
              variant: DkButtonVariant.tertiary,
              size: DkButtonSize.compact,
            ),
          ),
        ],
      ),
      DkSignatureMode.type => SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: t.space.xl,
          vertical: t.space.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: t.space.m,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              // ponytail: Material's field on tokens until DkTextField
              // (DK-0120) lands; then swap it in here.
              child: TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l.sign_pad_name,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(t.radius.s),
                  ),
                ),
              ),
            ),
            Row(
              spacing: t.space.m,
              children: [
                for (final (i, font) in DkSignaturePad.fonts.indexed)
                  Expanded(
                    child: _StylePreview(
                      name: _name.text.trim(),
                      font: font,
                      index: i,
                      selected: i == _font,
                      onTap: () => setState(() => _font = i),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      DkSignatureMode.image => Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(t.space.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: t.space.m,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Text(
                  l.sign_pad_image_body,
                  textAlign: TextAlign.center,
                  style: t.text.bodyM.copyWith(color: t.color.textSecondary),
                ),
              ),
              Wrap(
                spacing: t.space.m,
                runSpacing: t.space.s,
                alignment: WrapAlignment.center,
                children: [
                  DkButton(
                    label: l.sign_pad_take_photo,
                    icon: DkIcons.camera,
                    onPressed: widget.onTakePhoto,
                    variant: DkButtonVariant.secondary,
                  ),
                  DkButton(
                    label: l.sign_pad_choose_photo,
                    icon: DkIcons.importPhotos,
                    onPressed: widget.onChoosePhoto,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    };
  }
}

/// The white card the signature is made on: `pageWhite`, a 1 dp outline,
/// `radius.m`, and the light theme inside (it is paper in Dark too).
class _Paper extends StatelessWidget {
  const _Paper({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(t.radius.m);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.color.pageWhite,
        border: Border.all(color: t.color.outline),
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Theme(
          data: dokuloTheme(DkTokens.light),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}

/// "Ink", the two swatches (28, the chosen one ringed in primary), and the
/// chosen ink's name.
class _InkPicker extends StatelessWidget {
  const _InkPicker({required this.ink, required this.onChanged});

  final Color ink;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    const markup = DkMarkup();
    final inks = [(markup.black, l.markup_black), (markup.ink, l.markup_ink)];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.sign_pad_ink,
          style: t.text.labelM.copyWith(color: t.color.textSecondary),
        ),
        for (final (colour, name) in inks)
          Semantics(
            button: true,
            inMutuallyExclusiveGroup: true,
            selected: colour == ink,
            label: name,
            excludeSemantics: true,
            onTap: () => onChanged(colour),
            child: DkTappable(
              onTap: () => onChanged(colour),
              radius: kMinInteractiveDimension / 2,
              builder: (context, pressed) => SizedBox.square(
                dimension: kMinInteractiveDimension,
                child: Center(
                  // The chosen one: a 2 dp gap, then a 2 dp primary ring.
                  child: DkRing(
                    side: colour == ink
                        ? BorderSide(color: t.color.primary, width: 2)
                        : null,
                    radius: 14,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: colour,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Text(
          ink == markup.ink ? l.markup_ink : l.markup_black,
          style: t.text.caption.copyWith(color: t.color.textSecondary),
        ),
      ],
    );
  }
}

/// One handwriting style: the name in that font and blue ink, 72 tall; the
/// chosen one has a 2 dp primary border.
class _StylePreview extends StatelessWidget {
  const _StylePreview({
    required this.name,
    required this.font,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final String name, font;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(t.radius.s);
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: AppLocalizations.of(context).sign_pad_style(index + 1),
      excludeSemantics: true,
      onTap: onTap,
      child: DkTappable(
        onTap: onTap,
        radius: t.radius.s,
        builder: (context, pressed) => Container(
          height: 72,
          padding: EdgeInsets.symmetric(horizontal: t.space.s),
          decoration: BoxDecoration(
            color: pressed ? t.state.pressed : null,
            borderRadius: radius,
            border: selected
                ? Border.all(color: t.color.primary, width: 2)
                : Border.all(color: t.color.outline),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              name,
              maxLines: 1,
              style: TextStyle(
                fontFamily: font,
                fontSize: 28,
                color: const DkMarkup().ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
