/// Web page or HTML to a paginated PDF (DK-0399, UI spec §21.9).
///
/// The page loads in an off-screen web view (Android `WebView`, iOS
/// `WKWebView`) and is printed through the platform's print pipeline into
/// pages of the chosen size: Android's `PrintDocumentAdapter`, iOS's
/// `UIPrintPageRenderer`. The work runs on the platform's main thread; the
/// caller only waits.
///
/// This is the one tool that uses the internet (docs/compliance/network-uses.md):
/// the caller passes the address through `Network.webPage` (ai_core) first.
library;

import 'package:flutter/services.dart';

enum PageSize { a4, letter }

/// Why it failed; the tool maps these to the error catalogue.
enum WebToPdfError {
  /// No plugin on this platform.
  unavailable,

  /// The page didn't load: offline (ILL-19 "You're offline"), a bad address,
  /// a server error.
  loadFailed,

  /// The page took longer than the timeout to load.
  timeout,

  /// Loading worked; printing to PDF didn't.
  failed,
}

class WebToPdfException implements Exception {
  const WebToPdfException(this.error, [this.detail = '']);

  final WebToPdfError error;
  final String detail;

  @override
  String toString() => 'WebToPdfException(${error.name}) $detail';
}

class WebToPdf {
  const WebToPdf();

  static const channel = MethodChannel('dokulo/web_to_pdf');

  /// Prints the page at [url] (http or https) into [outputPath]; returns the
  /// page count.
  Future<int> fromUrl(
    Uri url,
    String outputPath, {
    PageSize pageSize = PageSize.a4,
    bool backgrounds = true,
    bool margins = true,
    Duration timeout = const Duration(seconds: 30),
  }) {
    if (url.scheme != 'http' && url.scheme != 'https') {
      throw ArgumentError.value(url, 'url', 'http or https only');
    }
    return _print(
      {'url': url.toString()},
      outputPath,
      pageSize,
      backgrounds,
      margins,
      timeout,
    );
  }

  /// Prints [html] into [outputPath]; returns the page count. [baseUrl] (the
  /// HTML file's folder, `file:///…/`) resolves its relative images and styles.
  Future<int> fromHtml(
    String html,
    String outputPath, {
    Uri? baseUrl,
    PageSize pageSize = PageSize.a4,
    bool backgrounds = true,
    bool margins = true,
    Duration timeout = const Duration(seconds: 30),
  }) => _print(
    {'html': html, 'baseUrl': ?baseUrl?.toString()},
    outputPath,
    pageSize,
    backgrounds,
    margins,
    timeout,
  );

  Future<int> _print(
    Map<String, Object?> source,
    String outputPath,
    PageSize pageSize,
    bool backgrounds,
    bool margins,
    Duration timeout,
  ) async {
    try {
      final pages = await channel.invokeMethod<int>('print', {
        ...source,
        'output': outputPath,
        'pageSize': pageSize.name,
        'backgrounds': backgrounds,
        'margins': margins,
        'timeoutMs': timeout.inMilliseconds,
      });
      return pages ?? 0;
    } on MissingPluginException {
      throw const WebToPdfException(WebToPdfError.unavailable);
    } on PlatformException catch (e) {
      throw WebToPdfException(switch (e.code) {
        'load_failed' => WebToPdfError.loadFailed,
        'timeout' => WebToPdfError.timeout,
        _ => WebToPdfError.failed,
      }, e.message ?? '');
    }
  }
}
