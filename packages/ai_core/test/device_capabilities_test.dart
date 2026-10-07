import 'package:ai_core/ai_core.dart';
import 'package:test/test.dart';

const gib = 1024 * 1024 * 1024;
const mib = 1024 * 1024;

DeviceCapabilities phone({
  int? totalRam,
  int? availableRam,
  int? freeStorage,
  List<String> abis = const ['arm64-v8a', 'armeabi-v7a'],
}) => DeviceCapabilities(
  totalRam: totalRam,
  availableRam: availableRam,
  freeStorage: freeStorage,
  abis: abis,
);

void main() {
  group('Gemma eligibility', () {
    test('a "6 GB" phone (5.6 GiB reported) is eligible', () {
      expect(
        eligibility(phone(totalRam: 5734 * mib), gemmaNeeds),
        AiEligibility.eligible,
      );
    });

    test('a "4 GB" phone is not: the A1 sheet names 6 GB and 4 GB', () {
      final device = phone(totalRam: 3700 * mib);
      expect(eligibility(device, gemmaNeeds), AiEligibility.tooLittleRam);
      expect(gemmaNeeds.advertisedGb, 6);
      expect(advertisedGb(device.totalRam!), 4);
    });

    test('a 32-bit phone gets every tool but no AI', () {
      final device = phone(totalRam: 8 * gib, abis: const ['armeabi-v7a']);
      expect(device.isArm64, isFalse);
      expect(eligibility(device, gemmaNeeds), AiEligibility.notArm64);
    });

    test('a phone that won\'t say is offered the model', () {
      expect(
        eligibility(const DeviceCapabilities(), gemmaNeeds),
        AiEligibility.eligible,
      );
    });
  });

  group('loading now', () {
    test('needs the working set plus 300 MB free', () {
      final enough = gemmaNeeds.workingSet + loadHeadroom;
      expect(canLoadNow(phone(availableRam: enough), gemmaNeeds), isTrue);
      expect(canLoadNow(phone(availableRam: enough - 1), gemmaNeeds), isFalse);
    });

    test('low memory now on an eligible phone: eligible, but not loadable', () {
      final device = phone(totalRam: 8 * gib, availableRam: 1 * gib);
      expect(eligibility(device, gemmaNeeds), AiEligibility.eligible);
      expect(canLoadNow(device, gemmaNeeds), isFalse);
    });

    test('unknown free memory does not block', () {
      expect(canLoadNow(phone(), gemmaNeeds), isTrue);
    });
  });

  test('storage shortfall ("needs about 120 MB")', () {
    expect(
      storageShortfall(phone(freeStorage: 80 * mib), 200 * mib),
      120 * mib,
    );
    expect(storageShortfall(phone(freeStorage: 500 * mib), 200 * mib), 0);
    expect(storageShortfall(phone(), 200 * mib), 0);
  });

  test('reads the platform map; zero or missing values are unknown', () {
    final device = DeviceCapabilities.fromMap({
      'totalRam': 8 * gib,
      'availableRam': 0,
      'freeStorage': 42 * gib,
      'abis': ['arm64-v8a'],
      'os': 'android',
      'osVersion': '14',
    });
    expect(device.totalRam, 8 * gib);
    expect(device.availableRam, isNull);
    expect(device.freeStorage, 42 * gib);
    expect(device.totalStorage, isNull);
    expect(device.isArm64, isTrue);
    expect((device.os, device.osVersion), ('android', '14'));
  });
}
