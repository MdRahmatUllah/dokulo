import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

/// V1's text search (UI spec §17.1 Search active; DK-1093): the screen holds
/// it, DkPdfCanvas attaches pdfrx's searcher and paints the matches, the
/// search bar reads [count] and [current] and calls [next] / [previous].
class DkPdfSearch extends ChangeNotifier {
  PdfTextSearcher? _searcher;
  VoidCallback? _unlisten;
  String _query = '';

  String get query => _query;

  /// Matches found so far (it searches page by page).
  int get count => _searcher?.matches.length ?? 0;

  /// The current match, 0-based; null before the first.
  int? get current => _searcher?.currentIndex;
  bool get searching => _searcher?.isSearching ?? false;
  List<PdfPageTextRange> get matches => _searcher?.matches ?? const [];

  /// The matches on [pageNumber] (1-based), with whether each is current.
  Iterable<(PdfPageTextRange, bool)> on(int pageNumber) sync* {
    final s = _searcher;
    final range = s?.getMatchesRangeForPage(pageNumber);
    if (s == null || range == null) return;
    for (var i = range.start; i < range.end; i++) {
      yield (s.matches[i], i == s.currentIndex);
    }
  }

  void search(String query) {
    _query = query.trim();
    final s = _searcher;
    if (s == null) return;
    _query.isEmpty
        ? s.resetTextSearch()
        : s.startTextSearch(_query, searchImmediately: true);
  }

  Future<void> next() async => _searcher?.goToNextMatch();
  Future<void> previous() async => _searcher?.goToPrevMatch();

  /// For DkPdfCanvas: its viewer's searcher; a query made before starts.
  void attach(PdfViewerController controller) {
    if (_searcher != null) return;
    final s = _searcher = PdfTextSearcher(controller);
    _unlisten = s.addListener(notifyListeners);
    if (_query.isNotEmpty) s.startTextSearch(_query, searchImmediately: true);
  }

  @override
  void dispose() {
    _unlisten?.call();
    _searcher?.dispose();
    super.dispose();
  }
}
