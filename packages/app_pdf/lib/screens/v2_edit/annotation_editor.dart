import 'dart:math' as math;

import 'package:doc_core/doc_core.dart';
import 'package:flutter/foundation.dart';

/// The edit mode's tools (UI spec §17.2; DkToolStrip's order).
enum EditTool { pan, pen, highlighter, text, shapes, note, eraser }

/// One annotation in the editor: [id] is stable across edits; [source] is
/// its index in the file as read (null for one made here), so a save knows
/// what to replace.
@immutable
class EditAnnot {
  const EditAnnot(this.id, this.annot, {this.source});
  final int id;
  final PdfAnnot annot;
  final int? source;

  EditAnnot copyWith(PdfAnnot annot) => EditAnnot(id, annot, source: source);
}

/// The selected annotation.
typedef AnnotRef = ({int page, int id});

/// The annotation editor's state (DK-0312): the tool, every page's
/// annotations, the selection, and an undo/redo history covering create,
/// move, resize, recolour and delete. Pure Dart: the overlay draws it and
/// feeds it gestures; [edits] is what a save hands to
/// [PdfAnnotations.apply].
class AnnotationEditor extends ChangeNotifier {
  AnnotationEditor({Map<int, List<PageAnnot>> read = const {}}) {
    _pages = {
      for (final MapEntry(key: p, value: list) in read.entries)
        p: [
          for (final a in list) EditAnnot(_nextId++, a.annot, source: a.index),
        ],
    };
    _original = {
      for (final e in _pages.entries) e.key: List.unmodifiable(e.value),
    };
  }

  var _nextId = 0;
  late Map<int, List<EditAnnot>> _pages;
  late final Map<int, List<EditAnnot>> _original;
  final _undo = <Map<int, List<EditAnnot>>>[];
  final _redo = <Map<int, List<EditAnnot>>>[];

  EditTool _tool = EditTool.pan;
  EditTool get tool => _tool;
  set tool(EditTool t) {
    if (t == _tool) return;
    _tool = t;
    _selected = null;
    notifyListeners();
  }

  AnnotRef? _selected;
  AnnotRef? get selected => _selected;

  /// The selected annotation, or null.
  EditAnnot? get selectedAnnot {
    final s = _selected;
    if (s == null) return null;
    for (final a in annotsOn(s.page)) {
      if (a.id == s.id) return a;
    }
    return null;
  }

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Whether anything differs from the file (the Discard dialog asks).
  bool get dirty {
    final now = _snapshot(_pages), before = _snapshot(_original);
    return now.length != before.length ||
        now.entries.any((e) => !listEquals(e.value, before[e.key]));
  }

  List<EditAnnot> annotsOn(int page) => _pages[page] ?? const [];

  // --- Changes. Each is one undo step.

  void _change(void Function(Map<int, List<EditAnnot>> pages) apply) {
    _undo.add(_copy(_pages));
    _redo.clear();
    final next = _copy(_pages);
    apply(next);
    _pages = next;
    notifyListeners();
  }

  /// Adds [annot] to [page] and selects it; returns its id.
  int add(int page, PdfAnnot annot, {bool select = true}) {
    final id = _nextId++;
    _change((pages) => (pages[page] ??= []).add(EditAnnot(id, annot)));
    if (select) _selected = (page: page, id: id);
    notifyListeners();
    return id;
  }

  void select(AnnotRef? ref) {
    _selected = ref;
    notifyListeners();
  }

  void _replace(AnnotRef ref, PdfAnnot Function(PdfAnnot) f) =>
      _change((pages) {
        final list = pages[ref.page]!;
        final i = list.indexWhere((a) => a.id == ref.id);
        if (i >= 0) list[i] = list[i].copyWith(f(list[i].annot));
      });

  /// Moves an annotation by ([dx], [dy]) points.
  void move(AnnotRef ref, double dx, double dy) =>
      _replace(ref, (a) => translate(a, dx, dy));

  /// Scales an annotation into [box].
  void resize(AnnotRef ref, Box box) => _replace(ref, (a) => fitTo(a, box));

  void recolour(AnnotRef ref, int color) =>
      _replace(ref, (a) => withColor(a, color));

  void delete(AnnotRef ref) {
    _change((pages) => pages[ref.page]?.removeWhere((a) => a.id == ref.id));
    if (_selected == ref) _selected = null;
    notifyListeners();
  }

  /// A copy of the annotation, a little down and right, selected.
  void duplicate(AnnotRef ref) {
    final src = _find(ref);
    if (src != null) add(ref.page, translate(src.annot, 12, -12));
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_copy(_pages));
    _pages = _undo.removeLast();
    _dropStaleSelection();
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_copy(_pages));
    _pages = _redo.removeLast();
    _dropStaleSelection();
    notifyListeners();
  }

  void _dropStaleSelection() {
    if (_selected != null && _find(_selected!) == null) _selected = null;
  }

  EditAnnot? _find(AnnotRef ref) {
    for (final a in annotsOn(ref.page)) {
      if (a.id == ref.id) return a;
    }
    return null;
  }

  /// The topmost annotation on [page] under [at], within [tolerance] points
  /// (a finger is wider than a pen line). Links and form widgets
  /// ([OtherAnnot]) are not selectable.
  int? hitTest(int page, PagePoint at, {double tolerance = 6}) {
    final list = annotsOn(page);
    for (var i = list.length - 1; i >= 0; i--) {
      if (hits(list[i].annot, at, tolerance)) return list[i].id;
    }
    return null;
  }

  /// What a save writes: per page, the file's annotations that changed or
  /// went (removed) and the new or changed ones (added).
  Map<int, PageAnnotEdits> edits() {
    final out = <int, PageAnnotEdits>{};
    for (final page in {..._pages.keys, ..._original.keys}) {
      final before = {
        for (final a in _original[page] ?? const <EditAnnot>[]) a.id: a,
      };
      final now = _pages[page] ?? const <EditAnnot>[];
      final nowIds = {for (final a in now) a.id};
      final remove = <int>{
        for (final a in before.values)
          if (!nowIds.contains(a.id)) a.source!,
      };
      final add = <PdfAnnot>[];
      for (final a in now) {
        final was = before[a.id];
        if (was == null) {
          add.add(a.annot);
        } else if (!identical(was.annot, a.annot)) {
          remove.add(a.source!);
          add.add(a.annot);
        }
      }
      if (remove.isNotEmpty || add.isNotEmpty) {
        out[page] = PageAnnotEdits(remove: remove, add: add);
      }
    }
    return out;
  }

  static Map<int, List<EditAnnot>> _copy(Map<int, List<EditAnnot>> m) => {
    for (final e in m.entries) e.key: [...e.value],
  };

  static Map<int, List<(int, PdfAnnot)>> _snapshot(
    Map<int, List<EditAnnot>> m,
  ) => {
    for (final e in m.entries)
      if (e.value.isNotEmpty) e.key: [for (final a in e.value) (a.id, a.annot)],
  };
}

// --- Geometry on annotations (page space).

PagePoint _t(PagePoint p, double dx, double dy) => (x: p.x + dx, y: p.y + dy);
Box _tb(Box b, double dx, double dy) => (
  left: b.left + dx,
  top: b.top + dy,
  right: b.right + dx,
  bottom: b.bottom + dy,
);

/// [a] moved by ([dx], [dy]).
PdfAnnot translate(PdfAnnot a, double dx, double dy) => switch (a) {
  InkAnnot(:final strokes, :final width) => InkAnnot(
    [
      for (final s in strokes) [for (final p in s) _t(p, dx, dy)],
    ],
    width: width,
    color: a.color,
    note: a.note,
  ),
  MarkupAnnot(:final kind, :final quads) => MarkupAnnot(
    kind,
    [
      for (final (p1, p2, p3, p4) in quads)
        (_t(p1, dx, dy), _t(p2, dx, dy), _t(p3, dx, dy), _t(p4, dx, dy)),
    ],
    color: a.color,
    note: a.note,
  ),
  ShapeAnnot(:final kind, :final rect, :final width, :final fill) => ShapeAnnot(
    kind,
    _tb(rect, dx, dy),
    width: width,
    color: a.color,
    fill: fill,
    note: a.note,
  ),
  FreeTextAnnot(:final rect, :final text, :final fontSize) => FreeTextAnnot(
    _tb(rect, dx, dy),
    text,
    fontSize: fontSize,
    color: a.color,
  ),
  NoteAnnot(:final at) => NoteAnnot(
    _t(at, dx, dy),
    note: a.note,
    color: a.color,
  ),
  OtherAnnot() => a,
};

/// [a] scaled into [box] (its bounds become [box]). A note keeps its icon
/// size; it only moves.
PdfAnnot fitTo(PdfAnnot a, Box box) {
  // Ink's bounds include half its line: fit the line itself, so the new
  // bounds are [box] again.
  final pad = a is InkAnnot ? a.width / 2 + 1 : 0.0;
  Box deflate(Box b) => (
    left: b.left + pad,
    top: b.top - pad,
    right: b.right - pad,
    bottom: b.bottom + pad,
  );
  final from = deflate(a.bounds);
  box = deflate(box);
  final sx = (box.right - box.left) / math.max(from.right - from.left, 1e-6);
  final sy = (box.top - box.bottom) / math.max(from.top - from.bottom, 1e-6);
  PagePoint m(PagePoint p) => (
    x: box.left + (p.x - from.left) * sx,
    y: box.bottom + (p.y - from.bottom) * sy,
  );
  return switch (a) {
    InkAnnot(:final strokes, :final width) => InkAnnot(
      [
        for (final s in strokes) [for (final p in s) m(p)],
      ],
      width: width,
      color: a.color,
      note: a.note,
    ),
    MarkupAnnot(:final kind, :final quads) => MarkupAnnot(
      kind,
      [for (final (p1, p2, p3, p4) in quads) (m(p1), m(p2), m(p3), m(p4))],
      color: a.color,
      note: a.note,
    ),
    ShapeAnnot(:final kind, :final width, :final fill) => ShapeAnnot(
      kind,
      box,
      width: width,
      color: a.color,
      fill: fill,
      note: a.note,
    ),
    FreeTextAnnot(:final text, :final fontSize) => FreeTextAnnot(
      box,
      text,
      fontSize: fontSize,
      color: a.color,
    ),
    NoteAnnot() => NoteAnnot(
      (x: box.left, y: box.top),
      note: a.note,
      color: a.color,
    ),
    OtherAnnot() => a,
  };
}

/// [a] in [color] (the alpha of [color] is kept as given).
PdfAnnot withColor(PdfAnnot a, int color) => switch (a) {
  InkAnnot(:final strokes, :final width) => InkAnnot(
    strokes,
    width: width,
    color: color,
    note: a.note,
  ),
  MarkupAnnot(:final kind, :final quads) => MarkupAnnot(
    kind,
    quads,
    color: color,
    note: a.note,
  ),
  ShapeAnnot(:final kind, :final rect, :final width, :final fill) => ShapeAnnot(
    kind,
    rect,
    width: width,
    color: color,
    fill: fill,
    note: a.note,
  ),
  FreeTextAnnot(:final rect, :final text, :final fontSize) => FreeTextAnnot(
    rect,
    text,
    fontSize: fontSize,
    color: color,
  ),
  NoteAnnot(:final at) => NoteAnnot(at, note: a.note, color: color),
  OtherAnnot() => a,
};

bool _inBox(Box b, PagePoint p, double tol) =>
    p.x >= b.left - tol &&
    p.x <= b.right + tol &&
    p.y >= b.bottom - tol &&
    p.y <= b.top + tol;

double _segmentDistance(PagePoint p, PagePoint a, PagePoint b) {
  final dx = b.x - a.x, dy = b.y - a.y;
  final len2 = dx * dx + dy * dy;
  final t = len2 == 0
      ? 0.0
      : (((p.x - a.x) * dx + (p.y - a.y) * dy) / len2).clamp(0.0, 1.0);
  final cx = a.x + t * dx, cy = a.y + t * dy;
  return math.sqrt((p.x - cx) * (p.x - cx) + (p.y - cy) * (p.y - cy));
}

/// Whether [at] touches [a]: an ink line within its half width plus
/// [tolerance]; anything else inside its bounds plus [tolerance].
bool hits(PdfAnnot a, PagePoint at, double tolerance) {
  switch (a) {
    case InkAnnot(:final strokes, :final width):
      final reach = width / 2 + tolerance;
      for (final s in strokes) {
        if (s.length == 1 && _segmentDistance(at, s[0], s[0]) <= reach) {
          return true;
        }
        for (var i = 1; i < s.length; i++) {
          if (_segmentDistance(at, s[i - 1], s[i]) <= reach) return true;
        }
      }
      return false;
    case MarkupAnnot(:final quads):
      return quads.any(
        (q) => _inBox(
          (
            left: math.min(q.$1.x, q.$3.x),
            top: math.max(q.$1.y, q.$2.y),
            right: math.max(q.$2.x, q.$4.x),
            bottom: math.min(q.$3.y, q.$4.y),
          ),
          at,
          tolerance,
        ),
      );
    case OtherAnnot():
      return false;
    default:
      return _inBox(a.bounds, at, tolerance);
  }
}
