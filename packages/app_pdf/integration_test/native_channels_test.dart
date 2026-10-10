// Device check (DK-0378, DK-1080, DK-1088): the method channels that stand
// in for plugins answer on a real Android build. Run on an emulator:
//   flutter test integration_test/native_channels_test.dart -d emulator-5554 --flavor dev
import 'package:app_pdf/providers/link_providers.dart';
import 'package:app_pdf/providers/mail_providers.dart';
import 'package:app_pdf/providers/notification_permission.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dokulo/notifications answers a status', (tester) async {
    final status = await const PlatformNotificationPermission().status();
    debugPrint('DEVICE | notifications status: ${status.name}');
    expect(NotificationAccess.values, contains(status));
  });

  testWidgets('dokulo/mail hands a mailto to a mail app, or says none', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sent = await container.read(mailComposerProvider)(
      Uri.parse('mailto:?subject=Dokulo%20report%20check'),
    );
    debugPrint('DEVICE | mail draft opened: $sent');
    expect(sent, isA<bool>());
  });

  testWidgets('dokulo/links opens a web address in the browser', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final opened = await container.read(linkOpenerProvider)(
      Uri.parse('https://example.com'),
    );
    debugPrint('DEVICE | link opened: $opened');
    expect(opened, isTrue);
  });
}
