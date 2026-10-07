import 'pdf_engine.dart';

/// What a block of a page is.
enum BlockKind { heading, paragraph, listItem, table }

/// A piece of a page in reading order (DK-0396): what PDF to text, Translate
/// and Smart Split read.
class Block {
  const Block(
    this.kind,
    this.page,
    this.text, {
    this.level = 0,
    this.rows = const [],
  });
  final BlockKind kind;

  /// 0-based.
  final int page;

  /// The text; a table's rows are lines, its cells tab-separated.
  final String text;

  /// Headings: 1 (largest) to 3.
  final int level;

  /// Tables: the cells, row by row.
  final List<List<String>> rows;

  @override
  String toString() => '${kind.name}${level > 0 ? level : ''}@$page: $text';
}

/// A run of characters on one line, set apart from its neighbours by a wide
/// gap (a table cell, a column's piece of the line).
class Segment {
  const Segment(
    this.text,
    this.left,
    this.right, {
    required this.fontSize,
    required this.bold,
  });
  final String text;
  final double left, right;
  final double fontSize;
  final bool bold;
}

/// One text line: characters sharing a baseline, left to right.
class TextLine {
  const TextLine(this.segments, this.baseline);
  final List<Segment> segments;
  final double baseline;

  String get text => segments.map((s) => s.text).join(' ');
  double get left => segments.first.left;
  double get fontSize => segments.first.fontSize;
  bool get bold => segments.every((s) => s.bold);
}

/// Layout analysis on PDFium's characters (DK-0396): reading order across
/// columns, headings by size and weight, list items, simple tables, running
/// headers and footers dropped. Heuristics, no model; PP-DocLayout regions
/// (DK-0401) can refine it later.
abstract final class PdfStructure {
  /// The blocks of [pages] (all by default) in reading order.
  static Future<List<Block>> extract(
    String path, {
    String? password,
    List<int>? pages,
  }) async {
    final info = await PdfEngine.inspect(path, password: password);
    final which = pages ?? [for (var i = 0; i < info.pageCount; i++) i];
    final linesByPage = <int, List<TextLine>>{};
    final allChars = <StyledChar>[];
    for (final page in which) {
      final chars = await PdfEngine.styledChars(path, page, password: password);
      allChars.addAll(chars);
      linesByPage[page] = buildLines(chars);
    }
    final kept = dropRunningLines(linesByPage, {
      for (final p in which) p: info.pages[p].height,
    });
    final body = bodySize(allChars);
    return [
      for (final page in which)
        ...blocks(
          kept[page]!,
          page: page,
          pageWidth: info.pages[page].width,
          bodySize: body,
        ),
    ];
  }

  /// The most common font size, weighted by characters: the body text's.
  static double bodySize(List<StyledChar> chars) {
    final counts = <double, int>{};
    for (final c in chars) {
      if (c.char.trim().isEmpty) continue;
      final size = (c.fontSize * 2).round() / 2;
      counts[size] = (counts[size] ?? 0) + 1;
    }
    if (counts.isEmpty) return 11;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Characters into lines (by baseline, top to bottom) and each line into
  /// segments (split where the gap is wider than 1.5 em).
  static List<TextLine> buildLines(List<StyledChar> chars) {
    final sorted = [...chars]..sort((a, b) => b.baseline.compareTo(a.baseline));
    final groups = <List<StyledChar>>[];
    for (final c in sorted) {
      final last = groups.isEmpty ? null : groups.last;
      if (last != null &&
          (last.first.baseline - c.baseline).abs() <=
              0.3 * last.first.fontSize) {
        last.add(c);
      } else {
        groups.add([c]);
      }
    }
    final lines = <TextLine>[];
    for (final group in groups) {
      group.sort((a, b) => a.box.left.compareTo(b.box.left));
      final segments = <Segment>[];
      var buffer = StringBuffer();
      List<StyledChar> run = [];
      void flush() {
        final text = buffer.toString().trim();
        final visible = run.where((c) => c.char.trim().isNotEmpty).toList();
        if (text.isNotEmpty && visible.isNotEmpty) {
          segments.add(
            Segment(
              text,
              visible.first.box.left,
              visible.last.box.right,
              fontSize: visible.first.fontSize,
              bold: visible.every((c) => c.bold),
            ),
          );
        }
        buffer = StringBuffer();
        run = [];
      }

      StyledChar? previous;
      for (final c in group) {
        if (previous != null && c.char.trim().isNotEmpty) {
          final gap = c.box.left - previous.box.right;
          if (gap > 1.5 * c.fontSize) {
            flush();
          }
        }
        buffer.write(c.char);
        run.add(c);
        if (c.char.trim().isNotEmpty) previous = c;
      }
      flush();
      if (segments.isNotEmpty) {
        lines.add(TextLine(segments, group.first.baseline));
      }
    }
    return lines;
  }

  static final _pageNumber = RegExp(
    r'^(?:(?:seite|page|s\.)\s*)?[-–]?\s*\d{1,4}\s*[-–]?(?:\s*(?:von|of|/)\s*\d{1,4})?$',
    caseSensitive: false,
  );

  /// Drops running headers and footers: lines in the top or bottom 12 % of a
  /// page that are page numbers ("Seite 2 von 3", "- 4 -"), or that repeat,
  /// digits aside, on at least half of the pages (and on two or more).
  static Map<int, List<TextLine>> dropRunningLines(
    Map<int, List<TextLine>> pages,
    Map<int, double> heights,
  ) {
    String key(TextLine l) => l.text.replaceAll(RegExp(r'\d+'), '#');
    bool inBand(TextLine l, int page) =>
        l.baseline > heights[page]! * 0.88 ||
        l.baseline < heights[page]! * 0.12;
    final seen = <String, Set<int>>{};
    pages.forEach((page, lines) {
      for (final l in lines.where((l) => inBand(l, page))) {
        (seen[key(l)] ??= {}).add(page);
      }
    });
    bool running(String k) =>
        seen[k]!.length >= 2 && seen[k]!.length * 2 >= pages.length;
    return {
      for (final MapEntry(key: page, value: lines) in pages.entries)
        page: [
          for (final l in lines)
            if (!inBand(l, page) ||
                !(_pageNumber.hasMatch(l.text.trim()) || running(key(l))))
              l,
        ],
    };
  }

  static final _bullet = RegExp(
    r'^(?:[•·▪‣◦\-–*]|\(?\d{1,3}[.)]|\(?[a-z][.)])\s+',
  );

  /// The blocks of one page's lines (top to bottom), in reading order.
  static List<Block> blocks(
    List<TextLine> lines, {
    required int page,
    required double pageWidth,
    required double bodySize,
  }) {
    final out = <Block>[];
    final flow = <TextLine>[];
    var i = 0;
    while (i < lines.length) {
      if (lines[i].segments.length < 2) {
        flow.add(lines[i++]);
        continue;
      }
      // A run of lines with the same number of segments.
      final count = lines[i].segments.length;
      final run = <TextLine>[];
      while (i < lines.length && lines[i].segments.length == count) {
        run.add(lines[i++]);
      }
      final widths = [
        for (final l in run)
          for (final s in l.segments) s.right - s.left,
      ]..sort();
      if (run.length >= 6 && widths[widths.length ~/ 2] >= 0.3 * pageWidth) {
        // Text columns: read each column top to bottom.
        for (var c = 0; c < count; c++) {
          flow.addAll([
            for (final l in run) TextLine([l.segments[c]], l.baseline),
          ]);
        }
      } else if (run.length >= 2) {
        out.addAll(_flow(flow, page, bodySize));
        flow.clear();
        final rows = [
          for (final l in run) [for (final s in l.segments) s.text],
        ];
        out.add(
          Block(
            BlockKind.table,
            page,
            rows.map((r) => r.join('\t')).join('\n'),
            rows: rows,
          ),
        );
      } else {
        flow.add(run.single);
      }
    }
    out.addAll(_flow(flow, page, bodySize));
    return out;
  }

  /// Headings, list items and paragraphs from single-column lines.
  static List<Block> _flow(List<TextLine> lines, int page, double bodySize) {
    final out = <Block>[];
    final headingSizes = {
      for (final l in lines)
        if (_isHeading(l, bodySize)) (l.fontSize * 2).round() / 2,
    }.toList()..sort((a, b) => b.compareTo(a));
    TextLine? previous;
    for (final line in lines) {
      final text = line.text;
      if (_isHeading(line, bodySize)) {
        final level = headingSizes.indexOf((line.fontSize * 2).round() / 2) + 1;
        out.add(Block(BlockKind.heading, page, text, level: level.clamp(1, 3)));
      } else if (_bullet.hasMatch(text)) {
        out.add(Block(BlockKind.listItem, page, text));
      } else if (previous != null &&
          out.isNotEmpty &&
          out.last.kind != BlockKind.heading &&
          out.last.kind != BlockKind.table &&
          (previous.fontSize - line.fontSize).abs() <= 0.5 &&
          previous.bold == line.bold &&
          previous.baseline - line.baseline <= 1.6 * line.fontSize &&
          (out.last.kind == BlockKind.listItem
              ? line.left > previous.left - line.fontSize
              : (line.left - previous.left).abs() <= 2 * line.fontSize)) {
        out[out.length - 1] = Block(
          out.last.kind,
          page,
          _join(out.last.text, text),
        );
      } else {
        out.add(Block(BlockKind.paragraph, page, text));
      }
      previous = line;
    }
    return out;
  }

  static bool _isHeading(TextLine l, double bodySize) =>
      l.fontSize >= bodySize * 1.15 ||
      (l.bold && l.text.length <= 80 && !l.text.endsWith('.'));

  /// Joins a line onto a paragraph, undoing a hyphenation ("Ver-" + "träge").
  static String _join(String paragraph, String line) {
    final hyphenated =
        RegExp(r'\p{L}-$', unicode: true).hasMatch(paragraph) &&
        RegExp(r'^\p{Ll}', unicode: true).hasMatch(line);
    return hyphenated
        ? paragraph.substring(0, paragraph.length - 1) + line
        : '$paragraph $line';
  }
}
