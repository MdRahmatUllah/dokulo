import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_to_pdf/web_to_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(WebToPdf.channel, null));

  test('passes the source and the options, answers the page count', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(WebToPdf.channel, (call) async {
      calls.add(call);
      return 3;
    });

    expect(
      await const WebToPdf().fromUrl(
        Uri.parse('https://example.com/a'),
        '/tmp/out.pdf',
      ),
      3,
    );
    expect(
      await const WebToPdf().fromHtml(
        '<p>Hi</p>',
        '/tmp/h.pdf',
        pageSize: PageSize.letter,
        margins: false,
        backgrounds: false,
        timeout: const Duration(seconds: 5),
      ),
      3,
    );

    expect(calls.first.arguments, {
      'url': 'https://example.com/a',
      'output': '/tmp/out.pdf',
      'pageSize': 'a4',
      'backgrounds': true,
      'margins': true,
      'timeoutMs': 30000,
    });
    expect(calls.last.arguments, {
      'html': '<p>Hi</p>',
      'output': '/tmp/h.pdf',
      'pageSize': 'letter',
      'backgrounds': false,
      'margins': false,
      'timeoutMs': 5000,
    });
  });

  test('only http and https addresses', () {
    expect(
      () => const WebToPdf().fromUrl(Uri.parse('file:///etc/hosts'), '/tmp/x'),
      throwsArgumentError,
    );
  });

  test('errors map to the tool\'s kinds', () async {
    Future<WebToPdfError> failWith(String code) async {
      messenger.setMockMethodCallHandler(
        WebToPdf.channel,
        (_) async => throw PlatformException(code: code),
      );
      try {
        await const WebToPdf().fromHtml('<p></p>', '/tmp/x');
      } on WebToPdfException catch (e) {
        return e.error;
      }
      throw StateError('no exception');
    }

    expect(await failWith('load_failed'), WebToPdfError.loadFailed);
    expect(await failWith('timeout'), WebToPdfError.timeout);
    expect(await failWith('failed'), WebToPdfError.failed);
    messenger.setMockMethodCallHandler(WebToPdf.channel, null);
    expect(
      () => const WebToPdf().fromHtml('<p></p>', '/tmp/x'),
      throwsA(
        isA<WebToPdfException>().having(
          (e) => e.error,
          'error',
          WebToPdfError.unavailable,
        ),
      ),
    );
  });
}
