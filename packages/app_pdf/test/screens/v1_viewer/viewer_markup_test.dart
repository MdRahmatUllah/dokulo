import 'package:app_pdf/components/dk_editor_bars.dart';
import 'package:app_pdf/components/dk_pdf_canvas.dart';
import 'package:app_pdf/screens/v1_viewer/viewer_screen.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const yellow = Color(0xFFFFEB3B);
  final selected = <SelectionLines>[
    (
      page: 0,
      lines: [
        (left: 70, top: 700, right: 300, bottom: 688),
        (left: 70, top: 686, right: 180, bottom: 674),
      ],
    ),
    (page: 1, lines: [(left: 70, top: 760, right: 120, bottom: 748)]),
    (page: 2, lines: []),
  ];

  test('one markup per page, a quad per line, in the PDF corner order', () {
    final edits = markupEdits(DkMarkupAction.highlight, selected, yellow);
    expect(edits.keys, [0, 1], reason: 'a page with no lines is left alone');
    final m = edits[0]!.add.single as MarkupAnnot;
    expect(m.kind, MarkupKind.highlight);
    expect(m.quads, hasLength(2));
    expect(m.quads.first, (
      (x: 70.0, y: 700.0),
      (x: 300.0, y: 700.0),
      (x: 70.0, y: 688.0),
      (x: 300.0, y: 688.0),
    ));
  });

  test('a highlight is see-through; underline and strike are opaque', () {
    int alpha(DkMarkupAction a) =>
        (markupEdits(a, selected, yellow)[0]!.add.single.color >> 24) & 0xFF;
    expect(alpha(DkMarkupAction.highlight), closeTo(0.4 * 255, 1));
    expect(alpha(DkMarkupAction.underline), 255);
    expect(
      (markupEdits(DkMarkupAction.strike, selected, yellow)[0]!.add.single
              as MarkupAnnot)
          .kind,
      MarkupKind.strikeOut,
    );
  });

  test('Copy and Ask make no annotation', () {
    expect(markupEdits(DkMarkupAction.copy, selected, yellow), isEmpty);
    expect(markupEdits(DkMarkupAction.ask, selected, yellow), isEmpty);
  });
}
