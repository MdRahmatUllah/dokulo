import 'package:ai_core/ai_core.dart';
import 'package:app_pdf/providers/device_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const gib = 1024 * 1024 * 1024;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(deviceChannel, null));

  test('reads the platform channel and rates Gemma', () async {
    messenger.setMockMethodCallHandler(deviceChannel, (call) async {
      expect(call.method, 'capabilities');
      return {
        'totalRam': 4 * gib,
        'availableRam': 2 * gib,
        'freeStorage': 30 * gib,
        'totalStorage': 64 * gib,
        'abis': ['arm64-v8a'],
        'os': 'android',
        'osVersion': '14',
      };
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final device = await container.read(deviceCapabilitiesProvider.future);
    expect(device.totalRam, 4 * gib);
    expect(device.os, 'android');
    expect(
      await container.read(gemmaEligibilityProvider.future),
      AiEligibility.tooLittleRam,
    );
  });

  test('a platform without the channel reads as unknown', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final device = await container.read(deviceCapabilitiesProvider.future);
    expect(device.totalRam, isNull);
    expect(
      await container.read(gemmaEligibilityProvider.future),
      AiEligibility.eligible,
    );
  });

  test('tests override it like any provider', () async {
    final container = ProviderContainer(
      overrides: [
        deviceCapabilitiesProvider.overrideWithValue(
          const AsyncData(
            DeviceCapabilities(totalRam: 12 * gib, abis: ['armeabi-v7a']),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(gemmaEligibilityProvider.future),
      AiEligibility.notArm64,
    );
  });
}
