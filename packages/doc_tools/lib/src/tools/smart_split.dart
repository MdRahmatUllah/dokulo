import 'package:doc_core/doc_core.dart';

/// Why Smart Split cuts before a page (UI spec §21.6's reason tags: "Blank
/// page", "Page 1 of 3", "New letterhead", "Different date").
enum SplitReason { blankPage, pageOneOf, newLetterhead, differentDate }

/// One page as the rules see it.
class PageSignals {
  const PageSignals({
    required this.blank,
    required this.topInk,
    required this.topHash,
    this.text = '',
  });

  /// Next to no ink: a separator sheet.
  final bool blank;

  /// The share of dark pixels in the top band (where a letterhead sits).
  final double topInk;

  /// A 64-bit difference hash of the top band.
  final int topHash;

  /// The page's text (PDFium's, or an OCR layer's); empty on a bare scan.
  final String text;
}

/// A document found in the bundle: its pages (0-based, blank separators
/// left out), the reason it starts, and a name suggested from its first
/// line of text.
class FoundDocument {
  const FoundDocument(this.pages, {this.reason, this.name});
  final List<int> pages;

  /// Null for the first document.
  final SplitReason? reason;
  final String? name;
}

/// The smart_split rules engine (DK-0552; UI spec §21.6), rules only: every
/// page boundary scored on blank separator pages, a "Page 1 of N" reset, a
/// letterhead unlike the current document's, and a new date. The optional
/// Gemma check on ambiguous boundaries joins with ai_core (DK-0545).
abstract final class SmartSplitRules {
  /// Darker than this (0–255 grey) is ink.
  static const inkLevel = 160;

  /// Below this share of ink a page is blank.
  static const blankInk = 0.002;

  /// Above this a top band carries a letterhead, not just a running line.
  static const letterheadInk = 0.012;

  /// Hamming distance of the top bands' hashes from which a letterhead is
  /// another one.
  static const newLetterhead = 18;

  /// The top band, as a share of the page's height.
  static const band = 0.18;

  static final _pageOne = RegExp(
    r'\b(?:seite|page|s\.)\s*1\s*(?:von|of|/)\s*(\d{1,3})\b',
    caseSensitive: false,
  );
  static final _date = RegExp(r'\b(\d{1,2})\.\s?(\d{1,2})\.\s?(\d{2,4})\b');

  /// [page]'s signals from its render (any dpi) and text.
  static PageSignals signals(RenderedPage page, String text) {
    var dark = 0, darkTop = 0;
    final top = (page.height * band).round();
    for (var y = 0; y < page.height; y++) {
      for (var x = 0; x < page.width; x++) {
        final i = (y * page.width + x) * 4;
        if ((page.bgra[i] + page.bgra[i + 1] + page.bgra[i + 2]) / 3 <
            inkLevel) {
          dark++;
          if (y < top) darkTop++;
        }
      }
    }
    return PageSignals(
      blank: dark / (page.width * page.height) < blankInk,
      topInk: darkTop / (page.width * top),
      topHash: _dhash(page, top),
      text: text,
    );
  }

  /// The documents in a bundle of [pages].
  static List<FoundDocument> split(List<PageSignals> pages) {
    final found = <FoundDocument>[];
    var current = <int>[];
    SplitReason? startedBy;
    int? letterhead;
    String? date;
    SplitReason? pending; // a blank sheet ends the document before it
    void close() {
      if (current.isNotEmpty) {
        found.add(
          FoundDocument(
            current,
            reason: startedBy,
            name: _name(pages[current.first].text),
          ),
        );
      }
      current = [];
      letterhead = null;
      date = null;
    }

    for (final (i, p) in pages.indexed) {
      if (p.blank) {
        if (current.isNotEmpty) pending = SplitReason.blankPage;
        continue;
      }
      final headed = p.topInk >= letterheadInk;
      final pageDate = _date.firstMatch(p.text)?[0];
      final reason =
          pending ??
          (_pageOne.hasMatch(p.text) && current.isNotEmpty
              ? SplitReason.pageOneOf
              : headed &&
                    letterhead != null &&
                    _distance(letterhead!, p.topHash) >= newLetterhead
              ? SplitReason.newLetterhead
              : pageDate != null && date != null && pageDate != date
              ? SplitReason.differentDate
              : null);
      if (reason != null && current.isNotEmpty) {
        close();
        startedBy = reason;
      }
      pending = null;
      current.add(i);
      if (headed) letterhead ??= p.topHash;
      date ??= pageDate;
    }
    close();
    return found;
  }

  /// The first line of text, as a name: at most 40 characters.
  static String? _name(String text) {
    final line = text
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.length >= 3, orElse: () => '');
    if (line.isEmpty) return null;
    return line.length <= 40 ? line : '${line.substring(0, 39).trimRight()}…';
  }

  /// A 9 × 8 grey grid of the top [rows] rows, one bit per pair of
  /// horizontal neighbours.
  static int _dhash(RenderedPage r, int rows) {
    final sum = List.generate(8, (_) => List.filled(9, 0.0));
    final count = List.generate(8, (_) => List.filled(9, 0));
    for (var y = 0; y < rows; y++) {
      final gy = (y * 8 ~/ rows).clamp(0, 7);
      for (var x = 0; x < r.width; x++) {
        final gx = (x * 9 ~/ r.width).clamp(0, 8);
        final i = (y * r.width + x) * 4;
        sum[gy][gx] += (r.bgra[i] + r.bgra[i + 1] + r.bgra[i + 2]) / 3;
        count[gy][gx]++;
      }
    }
    var h = 0;
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        final left = sum[y][x] / count[y][x],
            right = sum[y][x + 1] / count[y][x + 1];
        h = (h << 1) | (left > right ? 1 : 0);
      }
    }
    return h;
  }

  static int _distance(int a, int b) {
    var x = a ^ b, n = 0;
    while (x != 0) {
      n += x & 1;
      x = x >>> 1;
    }
    return n;
  }
}
