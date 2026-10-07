import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vision_ocr/vision_ocr.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(VisionOcr.channel, null));

  test(
    'reads words, boxes and confidence; passes the language hints',
    () async {
      MethodCall? seen;
      messenger.setMockMethodCallHandler(VisionOcr.channel, (call) async {
        seen = call;
        return [
          {
            'text': 'Grundmiete',
            'box': [0.1, 0.2, 0.3, 0.04],
            'confidence': 0.98,
          },
          {
            'text': '1.240,00',
            'box': [0.45, 0.2, 0.12, 0.04],
            'confidence': 1,
          },
          {'text': 'broken'}, // a malformed entry is skipped, not a crash
        ];
      });

      final words = await const VisionOcr().recognize(
        '/tmp/page.jpg',
        languages: ['de-DE'],
      );

      expect(seen!.method, 'recognize');
      expect(seen!.arguments, {
        'path': '/tmp/page.jpg',
        'languages': ['de-DE'],
      });
      expect([for (final w in words) w.text], ['Grundmiete', '1.240,00']);
      expect(words.first.box, (left: 0.1, top: 0.2, width: 0.3, height: 0.04));
      expect(words.last.confidence, 1.0);
    },
  );

  test('errors map to the facade\'s kinds', () async {
    Future<VisionOcrError> failWith(String code) async {
      messenger.setMockMethodCallHandler(
        VisionOcr.channel,
        (_) async => throw PlatformException(code: code, message: 'x'),
      );
      try {
        await const VisionOcr().recognize('/tmp/x');
      } on VisionOcrException catch (e) {
        return e.error;
      }
      throw StateError('no exception');
    }

    expect(await failWith('not_an_image'), VisionOcrError.notAnImage);
    expect(await failWith('failed'), VisionOcrError.failed);
    expect(await failWith('unavailable'), VisionOcrError.unavailable);
  });

  test(
    'no plugin (Android) means unavailable: the facade falls back to PP-OCRv5',
    () async {
      expect(
        () => const VisionOcr().recognize('/tmp/x'),
        throwsA(
          isA<VisionOcrException>().having(
            (e) => e.error,
            'error',
            VisionOcrError.unavailable,
          ),
        ),
      );
    },
  );
}
