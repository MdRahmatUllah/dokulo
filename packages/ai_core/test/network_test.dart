import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:test/test.dart';

/// Tries an HTTP request to [url] from inside a job.
Future<int> _httpGet(String url, JobContext context) async {
  final request = await HttpClient().getUrl(Uri.parse(url));
  return (await request.close()).statusCode;
}

/// Tries a raw socket to localhost:[port] from inside a job.
Future<void> _socket(int port, JobContext context) async {
  final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
  socket.destroy();
}

void main() {
  late HttpServer server; // a real server, so a refusal would be the guard's
  late String url;
  late Directory tempRoot;
  late IsolatePool pool;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) => request.response.close());
    url = 'http://127.0.0.1:${server.port}/';
    tempRoot = Directory.systemTemp.createTempSync('dk_net_test_');
    pool = IsolatePool(tempRoot: tempRoot);
  });

  tearDown(() async {
    await server.close(force: true);
    tempRoot.deleteSync(recursive: true);
  });

  final blocked = isA<JobFailed>().having(
    (e) => e.message,
    'message',
    contains('No network during a tool run'),
  );

  test('outside a job the network works (the guard is scoped)', () async {
    final request = await HttpClient().getUrl(Uri.parse(url));
    expect((await request.close()).statusCode, 200);
  });

  for (final lane in [Lane.pdfium, Lane.qpdf]) {
    test('a job on ${lane.name} cannot open an HTTP client', () async {
      await expectLater(pool.run(lane, _httpGet, url).result, throwsA(blocked));
    });
  }

  test('a job cannot open a socket', () async {
    await expectLater(
      pool.run(Lane.onnx, _socket, server.port).result,
      throwsA(blocked),
    );
  });

  test('a model download needs https and a catalogue host', () async {
    final network = Network(modelHosts: {'models.example.org'});
    for (final uri in [
      'http://models.example.org/m.gguf',
      'https://elsewhere.example.org/m.gguf',
    ]) {
      await expectLater(
        network.downloadModel(Uri.parse(uri)),
        throwsArgumentError,
        reason: uri,
      );
    }
  });

  test('Web page to PDF takes http and https addresses only', () {
    expect(
      Network.webPage(' example.org/a ').toString(),
      'https://example.org/a',
    );
    expect(
      Network.webPage('http://example.de').toString(),
      'http://example.de',
    );
    for (final bad in [
      '',
      'file:///etc/passwd',
      'javascript:alert(1)',
      'ftp://example.org',
    ]) {
      expect(() => Network.webPage(bad), throwsFormatException, reason: bad);
    }
  });
}
