import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';

import '../../components/dk_icon.dart';
import '../../theme/dk_tokens.dart';

/// A field's value as the form shows it now: what the user set, else what
/// the file has.
typedef FieldState = ({String text, bool checked, int? choice});

FieldState fieldState(PdfFormField f, PdfFieldValue? set) => switch (set) {
  TextFieldValue(:final text) => (text: text, checked: false, choice: null),
  CheckFieldValue(:final checked) => (
    text: f.value,
    checked: checked,
    choice: null,
  ),
  ChoiceFieldValue(:final index) => (
    text: f.options[index],
    checked: false,
    choice: index,
  ),
  null => (text: f.value, checked: f.checked, choice: f.selected.firstOrNull),
};

/// The form's fields on one page (DK-0324; UI spec §17.2 "Form filling"):
/// each fillable field a faint `primaryContainer` @ 40 % box ([highlight]),
/// the active one outlined 2 dp in `color.primary`; a text field being
/// filled holds the text right on the page. Taps outside the fields go
/// through to the page.
class FormLayer extends StatelessWidget {
  const FormLayer({
    super.key,
    required this.fields,
    required this.pageSize,
    required this.values,
    required this.active,
    required this.text,
    required this.onTap,
    this.highlight = true,
  });

  /// This page's fields.
  final List<PdfFormField> fields;

  /// The page in points.
  final Size pageSize;
  final Map<String, PdfFieldValue> values;

  /// The field being filled ([PdfFormField.id]).
  final String? active;

  /// The text field's controller while one is [active].
  final TextEditingController text;
  final ValueChanged<PdfFormField> onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final t = context.tokens;
      final s = c.maxWidth / pageSize.width;
      Rect rect(Box b) => Rect.fromLTRB(
        b.left * s,
        (pageSize.height - b.top) * s,
        b.right * s,
        (pageSize.height - b.bottom) * s,
      );
      return Stack(
        children: [
          for (final f in fields)
            if (!f.readOnly &&
                f.kind != PdfFieldKind.signature &&
                f.kind != PdfFieldKind.button &&
                f.kind != PdfFieldKind.unknown)
              Positioned.fromRect(
                rect: rect(f.box),
                child: _Field(
                  field: f,
                  state: fieldState(f, values[f.id]),
                  changed: values.containsKey(f.id),
                  active: f.id == active,
                  highlight: highlight,
                  text: text,
                  scale: s,
                  onTap: () => onTap(f),
                  fill: t.color.primaryContainer.withValues(alpha: 0.4),
                  ring: t.color.primary,
                ),
              ),
        ],
      );
    },
  );
}

class _Field extends StatelessWidget {
  /// A changed value as the page will show it once saved.
  Widget _value(BuildContext context) {
    final t = context.tokens;
    final size = (field.box.top - field.box.bottom) * scale * 0.55;
    return switch (field.kind) {
      PdfFieldKind.checkbox || PdfFieldKind.radio =>
        state.checked
            ? FittedBox(child: DkIcon(DkIcons.check, color: t.markup.black))
            : const SizedBox.expand(),
      _ => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            state.text,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(fontSize: size, color: t.markup.black),
          ),
        ),
      ),
    };
  }

  const _Field({
    required this.field,
    required this.state,
    required this.changed,
    required this.active,
    required this.highlight,
    required this.text,
    required this.scale,
    required this.onTap,
    required this.fill,
    required this.ring,
  });

  final PdfFormField field;
  final FieldState state;

  /// Set here, not yet in the file: drawn over the page's own appearance.
  final bool changed;
  final bool active, highlight;
  final TextEditingController text;
  final double scale;
  final VoidCallback onTap;
  final Color fill, ring;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final editing = active && field.kind == PdfFieldKind.text;
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: highlight || active ? fill : null,
        border: active ? Border.all(color: ring, width: 2) : null,
      ),
      child: editing
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: TextField(
                controller: text,
                autofocus: true,
                maxLines: field.multiline ? null : 1,
                textAlignVertical: TextAlignVertical.center,
                style: TextStyle(
                  // Close to the page's own text at this zoom.
                  fontSize: (field.box.top - field.box.bottom) * scale * 0.55,
                  color: t.markup.black,
                ),
                decoration: const InputDecoration.collapsed(hintText: null),
              ),
            )
          : changed
          ? ColoredBox(color: t.color.pageWhite, child: _value(context))
          : null,
    );
    if (editing) return box;
    final checkable =
        field.kind == PdfFieldKind.checkbox || field.kind == PdfFieldKind.radio;
    return Semantics(
      button: true,
      label: field.name,
      value: checkable ? null : state.text,
      checked: checkable ? state.checked : null,
      inMutuallyExclusiveGroup: field.kind == PdfFieldKind.radio,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: box,
      ),
    );
  }
}
