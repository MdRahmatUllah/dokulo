import 'dart:convert';
import 'dart:io';

import 'package:qpdf_ffi/qpdf_ffi.dart';

import 'pdf_engine.dart';
import 'qpdf_service.dart';

/// Writing bookmarks (Merge PDF keeps each file's, DK-1101). PDFium only
/// reads them ([PdfEngine.outline]); qpdf writes them as new objects through
/// its JSON update, as [PdfaWriter] does for PDF/A.
abstract final class PdfOutline {
  /// [entries] moved onto a merged file's pages: each source's outline
  /// ([sources]: its entries and the 0-based source pages that went into
  /// the output, in order) shifted to where those pages landed. An entry
  /// whose page didn't come along is dropped, its children kept.
  static List<OutlineEntry> merged(
    List<({List<OutlineEntry> outline, List<int> pages})> sources,
  ) {
    final out = <OutlineEntry>[];
    var offset = 0;
    for (final source in sources) {
      List<OutlineEntry> move(List<OutlineEntry> entries) => [
        for (final e in entries)
          ...switch (e.page == null ? -1 : source.pages.indexOf(e.page!)) {
            -1 => move(e.children),
            final at => [
              OutlineEntry(
                title: e.title,
                page: offset + at,
                children: move(e.children),
              ),
            ],
          },
      ];
      out.addAll(move(source.outline));
      offset += source.pages.length;
    }
    return out;
  }

  /// The 0-based pages a qpdf range ("1-3,7", `z` the last page; null: all)
  /// takes from a file of [count] pages; null when it's syntax this doesn't
  /// read (`r`, `x`, `:even`), so its bookmarks are left out.
  static List<int>? rangePages(String? range, int count) {
    if (range == null || range.trim().isEmpty) {
      return [for (var p = 0; p < count; p++) p];
    }
    int? page(String s) => switch (s.trim()) {
      'z' => count,
      final n => int.tryParse(n),
    };
    final pages = <int>[];
    for (final part in range.split(',')) {
      final ends = part.split('-');
      final from = page(ends.first);
      final to = ends.length == 2 ? page(ends.last) : from;
      if (ends.length > 2 || from == null || to == null) return null;
      final step = from <= to ? 1 : -1;
      for (var p = from; p != to + step; p += step) {
        if (p >= 1 && p <= count) pages.add(p - 1);
      }
    }
    return pages;
  }

  /// Writes [output]: [input] with [entries] as its bookmarks (replacing
  /// any it had); inside a `Lane.qpdf` job. [work] holds qpdf's JSON.
  static List<String> write(
    String input,
    String output,
    List<OutlineEntry> entries,
    Directory work,
  ) => QpdfService.run(() {
    final exported = '${work.path}/outline-structure.json';
    Qpdf.run({
      'inputFile': input,
      'outputFile': exported,
      'jsonOutput': '2',
      'jsonStreamData': 'none',
    });
    final update = '${work.path}/outline-update.json';
    File(update).writeAsStringSync(
      jsonEncode(
        outlineUpdate(
          jsonDecode(File(exported).readAsStringSync()) as Map<String, Object?>,
          entries,
        ),
      ),
    );
    return Qpdf.run({
      'inputFile': input,
      'outputFile': output,
      'updateFromJson': update,
    });
  });

  /// The qpdf JSON update that gives [exported] (qpdf's JSON v2 of a file)
  /// [entries] as its outline: an /Outlines dictionary and one item per
  /// entry, linked /First, /Last, /Next, /Prev, /Parent, each opening its
  /// page fitted.
  static Map<String, Object?> outlineUpdate(
    Map<String, Object?> exported,
    List<OutlineEntry> entries,
  ) {
    final qpdf = exported['qpdf']! as List<Object?>;
    final header = qpdf[0]! as Map<String, Object?>;
    final objects = qpdf[1]! as Map<String, Object?>;
    Map<String, Object?> value(String ref) => switch (objects['obj:$ref']) {
      {'value': final Map<String, Object?> v} => v,
      _ => const {},
    };
    final trailer =
        (objects['trailer']! as Map<String, Object?>)['value']!
            as Map<String, Object?>;
    final rootRef = trailer['/Root']! as String;
    final catalog = Map<String, Object?>.of(value(rootRef));
    // The page objects in order: the /Pages tree's leaves, depth first.
    final pages = <String>[];
    void walk(String ref) {
      final node = value(ref);
      if (node['/Type'] == '/Page') {
        pages.add(ref);
        return;
      }
      for (final kid in (node['/Kids'] as List? ?? const [])) {
        if (kid is String) walk(kid);
      }
    }

    if (catalog['/Pages'] case final String tree) walk(tree);

    var next = header['maxobjectid']! as int;
    String newRef() => '${++next} 0 R';
    final changed = <String, Object?>{};
    final root = newRef();

    // Returns the visible count of [items] (all open).
    int link(
      List<OutlineEntry> items,
      String parent,
      Map<String, Object?> into,
    ) {
      final refs = [for (final _ in items) newRef()];
      var count = 0;
      for (final (i, e) in items.indexed) {
        final item = <String, Object?>{
          '/Title': 'u:${e.title}',
          '/Parent': parent,
          if (i > 0) '/Prev': refs[i - 1],
          if (i < items.length - 1) '/Next': refs[i + 1],
          if (e.page case final p? when p >= 0 && p < pages.length)
            '/Dest': [pages[p], '/Fit'],
        };
        final children = link(e.children, refs[i], item);
        changed['obj:${refs[i]}'] = {'value': item};
        count += 1 + children;
      }
      if (refs.isNotEmpty) {
        into['/First'] = refs.first;
        into['/Last'] = refs.last;
        into['/Count'] = count;
      }
      return count;
    }

    final outlines = <String, Object?>{'/Type': '/Outlines'};
    link(entries, root, outlines);
    changed['obj:$root'] = {'value': outlines};
    catalog['/Outlines'] = root;
    changed['obj:$rootRef'] = {'value': catalog};
    return {
      'qpdf': [
        {...header, 'maxobjectid': next},
        changed,
      ],
    };
  }
}
