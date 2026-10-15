import 'dart:io';

import 'package:pdf/pdf.dart' as pw;

import 'pdf_engine.dart';

/// Organize pages (P1; DK-0330): a document's pages as a list of
/// [PageSource]s that the user edits (move, delete, duplicate, rotate,
/// insert pages from another file or a blank one). Every edit is a command
/// on the list: [undo] and [redo] step through them. [save] writes the list
/// as a new file with [PdfEngine.assemble] (PDFium); the source files are
/// never touched.
class PageEdit {
  PageEdit(this.path, int pageCount)
    : _pages = [for (var i = 0; i < pageCount; i++) PageSource(path, i)];

  /// The document being organized.
  final String path;

  List<PageSource> _pages;
  final _undo = <List<PageSource>>[];
  final _redo = <List<PageSource>>[];

  List<PageSource> get pages => List.unmodifiable(_pages);
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Anything to save.
  bool get changed => _undo.isNotEmpty;

  void _apply(List<PageSource> next) {
    _undo.add(_pages);
    _redo.clear();
    _pages = next;
  }

  void undo() {
    if (!canUndo) return;
    _redo.add(_pages);
    _pages = _undo.removeLast();
  }

  void redo() {
    if (!canRedo) return;
    _undo.add(_pages);
    _pages = _redo.removeLast();
  }

  /// Moves the page at [from] to [to] (its index after the move).
  void move(int from, int to) {
    final next = [..._pages];
    next.insert(to, next.removeAt(from));
    _apply(next);
  }

  /// Moves the pages at [indexes] together, in their order, so the first of
  /// them lands at [to] in the result (a multi-page drag).
  void moveAll(Set<int> indexes, int to) {
    final moving = [
      for (final (i, p) in _pages.indexed)
        if (indexes.contains(i)) p,
    ];
    final rest = [
      for (final (i, p) in _pages.indexed)
        if (!indexes.contains(i)) p,
    ];
    _apply(rest..insertAll(to.clamp(0, rest.length), moving));
  }

  /// Deletes the pages at [indexes]. A PDF keeps at least one page.
  void delete(Set<int> indexes) {
    if (indexes.length >= _pages.length) {
      throw ArgumentError('a PDF keeps at least one page');
    }
    _apply([
      for (final (i, p) in _pages.indexed)
        if (!indexes.contains(i)) p,
    ]);
  }

  /// A copy of each page at [indexes], right after it: a new [PageSource],
  /// so every entry stays one item (a grid keys its tiles by them).
  void duplicate(Set<int> indexes) => _apply([
    for (final (i, p) in _pages.indexed) ...[
      p,
      if (indexes.contains(i))
        PageSource(p.path, p.page, addQuarterTurns: p.addQuarterTurns),
    ],
  ]);

  /// Turns the pages at [indexes] by [quarterTurns] clockwise (negative:
  /// counter-clockwise).
  void rotate(Set<int> indexes, int quarterTurns) => _apply([
    for (final (i, p) in _pages.indexed)
      indexes.contains(i)
          ? PageSource(
              p.path,
              p.page,
              addQuarterTurns: (p.addQuarterTurns + quarterTurns) % 4,
            )
          : p,
  ]);

  /// Inserts [pages] (from another PDF, a scan, converted photos) at [at].
  void insert(int at, List<PageSource> pages) =>
      _apply([..._pages]..insertAll(at.clamp(0, _pages.length), pages));

  /// Inserts a blank page at [at], the size of the page before it (or after
  /// it, at the start), as it is displayed. The blank page is a one-page PDF
  /// written in [temp].
  Future<void> insertBlank(
    int at,
    Directory temp, {
    Map<String, String> passwords = const {},
  }) async {
    final neighbour =
        _pages[(at == 0 ? 0 : at - 1).clamp(0, _pages.length - 1)];
    final info = (await PdfEngine.inspect(
      neighbour.path,
      password: passwords[neighbour.path],
    )).pages[neighbour.page];
    final turned = neighbour.addQuarterTurns.isOdd;
    final width = turned ? info.height : info.width;
    final height = turned ? info.width : info.height;
    await temp.create(recursive: true);
    final blank = File(
      '${temp.path}${Platform.pathSeparator}blank_'
      '${width.round()}x${height.round()}.pdf',
    );
    if (!await blank.exists()) {
      final doc = pw.PdfDocument();
      pw.PdfPage(doc, pageFormat: pw.PdfPageFormat(width, height));
      await blank.writeAsBytes(await doc.save());
    }
    insert(at, [PageSource(blank.path, 0)]);
  }

  /// Writes the pages as they are now to [outPath] (a new file).
  Future<void> save(
    String outPath, {
    Map<String, String> passwords = const {},
  }) => PdfEngine.assemble(_pages, outPath, passwords: passwords);
}
