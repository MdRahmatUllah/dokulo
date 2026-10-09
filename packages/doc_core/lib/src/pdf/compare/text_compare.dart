import 'dart:typed_data';

import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;

import '../pdf_engine.dart';
import '../redact/pdf_redactor.dart';

enum ChangeKind { added, removed, changed }

/// One difference between two versions of a PDF (DK-0529): what was there
/// ([before], on [oldPage]) and what is there now ([after], on [newPage]),
/// with the boxes to highlight on each page (one per line, page space).
class TextChange {
  const TextChange(
    this.kind, {
    required this.oldPage,
    required this.newPage,
    this.before = '',
    this.after = '',
    this.oldBoxes = const [],
    this.newBoxes = const [],
  });

  final ChangeKind kind;

  /// The page (0-based) in each version the change anchors to.
  final int oldPage, newPage;
  final String before, after;
  final List<Box> oldBoxes, newBoxes;

  @override
  String toString() => '${kind.name} p$oldPage/p$newPage "$before" → "$after"';
}

/// A word of a page and where it sits in the page's text.
typedef _Word = ({String text, int start, int end});

List<_Word> _words(String text) => [
  for (final m in RegExp(r'\S+').allMatches(text))
    (text: m[0]!, start: m.start, end: m.end),
];

/// The words of one page pair as an edit script: a longest common
/// subsequence of words, then runs of removed and added words, a removal
/// next to an addition being a change. ponytail: O(n·m) per page (a page is
/// a few hundred words); Myers' O(ND) if long pages make it slow.
List<(ChangeKind, List<_Word>, List<_Word>)> _diffWords(
  List<_Word> a,
  List<_Word> b,
) {
  final n = a.length, m = b.length;
  // lcs[i][j]: the LCS length of a[i..] and b[j..].
  final lcs = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      lcs[i][j] = a[i].text == b[j].text
          ? lcs[i + 1][j + 1] + 1
          : (lcs[i + 1][j] >= lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
    }
  }
  final out = <(ChangeKind, List<_Word>, List<_Word>)>[];
  var removed = <_Word>[], added = <_Word>[];
  void flush() {
    if (removed.isEmpty && added.isEmpty) return;
    out.add((
      removed.isEmpty
          ? ChangeKind.added
          : added.isEmpty
          ? ChangeKind.removed
          : ChangeKind.changed,
      removed,
      added,
    ));
    removed = [];
    added = [];
  }

  var i = 0, j = 0;
  while (i < n || j < m) {
    if (i < n && j < m && a[i].text == b[j].text) {
      flush();
      i++;
      j++;
    } else if (j < m && (i == n || lcs[i][j + 1] >= lcs[i + 1][j])) {
      added.add(b[j++]);
    } else {
      removed.add(a[i++]);
    }
  }
  flush();
  return out;
}

/// Compare's text mode (DK-0529; UI spec §21.24): the pages' text from
/// PDFium, page by page (page 1 with page 1, …; pages only one version has
/// are wholly added or removed), diffed by words.
abstract final class PdfCompare {
  /// The changes from [older] to [newer], in page order.
  static Future<List<TextChange>> text(
    String older,
    String newer, {
    String? olderPassword,
    String? newerPassword,
  }) async {
    final a = await PdfEngine.inspect(older, password: olderPassword);
    final b = await PdfEngine.inspect(newer, password: newerPassword);
    final pages = a.pageCount > b.pageCount ? a.pageCount : b.pageCount;
    final changes = <TextChange>[];
    for (var p = 0; p < pages; p++) {
      final oldText = p < a.pageCount
          ? await PdfEngine.pageText(older, p, password: olderPassword)
          : null;
      final newText = p < b.pageCount
          ? await PdfEngine.pageText(newer, p, password: newerPassword)
          : null;
      changes.addAll(pageChanges(p, oldText, newText));
    }
    return changes;
  }

  /// The changes on one page pair (null: the page isn't in that version).
  static List<TextChange> pageChanges(
    int page,
    PageText? older,
    PageText? newer,
  ) {
    List<Box> boxes(PageText? t, List<_Word> ws) => t == null || ws.isEmpty
        ? const []
        : PdfRedactor.lineBoxes(t.charBoxes, ws.first.start, ws.last.end);
    String join(PageText? t, List<_Word> ws) =>
        ws.isEmpty ? '' : t!.text.substring(ws.first.start, ws.last.end);
    return [
      for (final (kind, removed, added) in _diffWords(
        older == null ? const [] : _words(older.text),
        newer == null ? const [] : _words(newer.text),
      ))
        TextChange(
          kind,
          oldPage: page,
          newPage: page,
          before: join(older, removed),
          after: join(newer, added),
          oldBoxes: boxes(older, removed),
          newBoxes: boxes(newer, added),
        ),
    ];
  }

  /// "23 changes" and the filter chips' counts.
  static Map<ChangeKind, int> counts(List<TextChange> changes) => {
    for (final k in ChangeKind.values)
      k: changes.where((c) => c.kind == k).length,
  };
}

/// The words Compare's report needs, in the app's language.
typedef CompareReportText = ({
  String title,
  String Function(int count) summary,
  String Function(ChangeKind kind) kind,
  String Function(int oldPage, int newPage) pages,
});

/// Compare's "Export report" (DK-0529): an A4 PDF listing every change in
/// page order with its kind, pages, and the text before and after.
/// ponytail: the built-in Helvetica (Latin-1); embed a Unicode font
/// (Noto Sans) when reports need other scripts.
Future<Uint8List> compareReportPdf(
  List<TextChange> changes,
  CompareReportText words,
) {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        pw.Header(level: 0, text: words.title),
        pw.Paragraph(text: words.summary(changes.length)),
        for (final c in changes)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${words.kind(c.kind)} · ${words.pages(c.oldPage + 1, c.newPage + 1)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                if (c.before.isNotEmpty)
                  pw.Text(
                    '- ${c.before}',
                    style: const pw.TextStyle(
                      decoration: pw.TextDecoration.lineThrough,
                    ),
                  ),
                if (c.after.isNotEmpty) pw.Text('+ ${c.after}'),
              ],
            ),
          ),
      ],
    ),
  );
  return doc.save();
}
