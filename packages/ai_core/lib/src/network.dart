/// Dokulo's network rules (DK-0012; Privacy page, "What uses the internet").
///
/// Only three things use the internet: model downloads, Web page to PDF and
/// store purchases. A tool run never does: every job runs inside [offline],
/// where opening an HTTP client or a socket fails as in airplane mode. Our own
/// HTTP goes through [Network] (`tools/check_layers.py` fails on an HTTP
/// client anywhere else in `packages/*/lib`).
library;

import 'dart:async';
import 'dart:io';

/// The three uses, as the Privacy page lists them.
enum NetworkUse {
  /// An optional AI model, from a host in the model catalogue.
  modelDownload,

  /// The page the user enters in Web page to PDF; the WebView loads it.
  webToPdf,

  /// The App Store or Google Play, through their purchase SDKs.
  purchase,
}

/// Runs [body] with the network switched off: an HTTP client or a socket
/// fails with a [SocketException], as in airplane mode. The job queue runs
/// every tool job this way, on every lane.
Future<T> offline<T>(FutureOr<T> Function() body) => HttpOverrides.runZoned(
  () => IOOverrides.runZoned(
    () async => await body(),
    socketConnect: (host, port, {sourceAddress, sourcePort = 0, timeout}) =>
        throw _blocked(host),
    socketStartConnect: (host, port, {sourceAddress, sourcePort = 0}) =>
        throw _blocked(host),
  ),
  createHttpClient: (_) => throw _blocked(null),
);

SocketException _blocked(Object? host) => SocketException(
  'No network during a tool run (DK-0012)${host == null ? '' : ': $host'}',
);

/// The one way our code opens an HTTP connection.
class Network {
  Network({required this.modelHosts, HttpClient Function()? client})
    : _client = client ?? HttpClient.new;

  /// The hosts of the model catalogue, the only ones a model download may
  /// reach.
  final Set<String> modelHosts;
  final HttpClient Function() _client;

  /// Starts downloading a model; https and a catalogue host only.
  Future<HttpClientResponse> downloadModel(Uri uri) async {
    if (uri.scheme != 'https' || !modelHosts.contains(uri.host)) {
      throw ArgumentError.value(
        uri,
        'uri',
        'not a model catalogue host over https',
      );
    }
    final request = await _client().getUrl(uri);
    return request.close();
  }

  /// The address the user typed for Web page to PDF, as the WebView should
  /// load it: http or https only (`https://` is added when there is none).
  static Uri webPage(String input) {
    final text = input.trim();
    final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw FormatException('not a web address', input);
    }
    return uri;
  }
}
