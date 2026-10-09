import 'package:app_pdf/screens/v2_edit/annotation_editor.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter_test/flutter_test.dart';

const red = 0xFFE53935, blue = 0xFF2251E6;

const stroke = InkAnnot(
  [
    [(x: 100, y: 100), (x: 200, y: 100)],
  ],
  width: 4,
  color: red,
);
const box = ShapeAnnot(
  ShapeKind.square,
  (left: 300, top: 400, right: 400, bottom: 300),
  width: 2,
  color: red,
);
const note = NoteAnnot((x: 50, y: 700), note: 'Check', color: blue);

void main() {
  test('a new editor: pan, nothing to undo, not dirty', () {
    final e = AnnotationEditor();
    expect(e.tool, EditTool.pan);
    expect((e.canUndo, e.canRedo, e.dirty), (false, false, false));
  });

  test('add selects; undo and redo walk back and forth', () {
    final e = AnnotationEditor();
    final id = e.add(0, stroke);
    expect(e.selected, (page: 0, id: id));
    expect(e.annotsOn(0), hasLength(1));
    e.undo();
    expect(e.annotsOn(0), isEmpty);
    expect(e.selected, isNull, reason: 'the selection went with it');
    e.redo();
    expect(e.annotsOn(0).single.annot, stroke);
  });

  test('undo covers move, resize, recolour and delete', () {
    final e = AnnotationEditor();
    final id = e.add(0, box);
    final ref = (page: 0, id: id);
    e.move(ref, 10, -20);
    expect((e.selectedAnnot!.annot as ShapeAnnot).rect, (
      left: 310.0,
      top: 380.0,
      right: 410.0,
      bottom: 280.0,
    ));
    e.resize(ref, (left: 0, top: 200, right: 50, bottom: 100));
    expect((e.selectedAnnot!.annot as ShapeAnnot).rect, (
      left: 0.0,
      top: 200.0,
      right: 50.0,
      bottom: 100.0,
    ));
    e.recolour(ref, blue);
    expect(e.selectedAnnot!.annot.color, blue);
    e.delete(ref);
    expect(e.annotsOn(0), isEmpty);
    for (final want in [blue, red, red, red]) {
      e.undo();
      expect(e.annotsOn(0).single.annot.color, want);
    }
    e.undo();
    expect(e.annotsOn(0), isEmpty);
    expect(e.canUndo, isFalse);
    expect(e.canRedo, isTrue);
  });

  test('a change after an undo drops the redo history', () {
    final e = AnnotationEditor();
    e.add(0, stroke);
    e.undo();
    e.add(0, note);
    expect(e.canRedo, isFalse);
  });

  test('resizing scales ink and markup; a note only moves', () {
    final ink =
        fitTo(stroke, (left: 0, top: 50, right: 50, bottom: 0)) as InkAnnot;
    expect(ink.bounds.left, closeTo(0, 0.01));
    expect(ink.bounds.right, closeTo(50, 0.01));
    final n =
        fitTo(note, (left: 10, top: 20, right: 500, bottom: 0)) as NoteAnnot;
    expect(n.at, (x: 10.0, y: 20.0));
    expect(n.bounds.right - n.bounds.left, NoteAnnot.iconSize);
  });

  group('hit testing', () {
    test('ink by its line, within half its width plus the tolerance', () {
      expect(hits(stroke, (x: 150, y: 105), 6), isTrue);
      expect(hits(stroke, (x: 150, y: 115), 6), isFalse);
      expect(hits(stroke, (x: 260, y: 100), 6), isFalse);
    });

    test('shapes and notes by their box; links never', () {
      expect(hits(box, (x: 350, y: 350), 0), isTrue);
      expect(hits(note, (x: 60, y: 690), 0), isTrue);
      expect(
        hits(const OtherAnnot(2, (left: 0, top: 100, right: 100, bottom: 0)), (
          x: 50,
          y: 50,
        ), 6),
        isFalse,
      );
    });

    test('the topmost annotation wins', () {
      final e = AnnotationEditor();
      e.add(0, box);
      final top = e.add(
        0,
        const ShapeAnnot(
          ShapeKind.circle,
          (left: 320, top: 380, right: 380, bottom: 320),
          width: 1,
          color: blue,
        ),
      );
      expect(e.hitTest(0, (x: 350, y: 350)), top);
      expect(e.hitTest(0, (x: 305, y: 395)), isNot(top));
      expect(e.hitTest(1, (x: 350, y: 350)), isNull);
    });
  });

  group('edits for the save', () {
    test('new annotations are added; untouched ones stay out', () {
      final e = AnnotationEditor(
        read: {
          0: [(index: 0, annot: note)],
        },
      );
      e.add(0, stroke);
      e.add(2, box);
      final edits = e.edits();
      expect(edits.keys.toSet(), {0, 2});
      expect(edits[0]!.remove, isEmpty);
      expect(edits[0]!.add, [stroke]);
      expect(edits[2]!.add, [box]);
    });

    test('a changed file annotation is replaced; a deleted one removed', () {
      final e = AnnotationEditor(
        read: {
          0: [
            (index: 0, annot: note),
            (index: 1, annot: box),
            (index: 2, annot: stroke),
          ],
        },
      );
      final ids = [for (final a in e.annotsOn(0)) a.id];
      e.move((page: 0, id: ids[1]), 5, 5);
      e.delete((page: 0, id: ids[2]));
      final edits = e.edits()[0]!;
      expect(edits.remove, {1, 2});
      expect(edits.add.single, isA<ShapeAnnot>());
      expect(e.dirty, isTrue);
    });

    test('undoing everything leaves nothing to save', () {
      final e = AnnotationEditor(
        read: {
          0: [(index: 0, annot: note)],
        },
      );
      e.recolour((page: 0, id: e.annotsOn(0).single.id), red);
      e.undo();
      expect(e.edits(), isEmpty);
      expect(e.dirty, isFalse);
    });
  });

  test('duplicate copies down and right, and selects the copy', () {
    final e = AnnotationEditor();
    final id = e.add(0, box);
    e.duplicate((page: 0, id: id));
    expect(e.annotsOn(0), hasLength(2));
    expect(e.selected!.id, isNot(id));
    expect((e.selectedAnnot!.annot as ShapeAnnot).rect.left, 312);
  });

  test('changing the tool drops the selection', () {
    final e = AnnotationEditor();
    e.add(0, box);
    e.tool = EditTool.pen;
    expect(e.selected, isNull);
  });
}
