import 'package:app_pdf/components/dk_logo.dart';
import 'package:app_pdf/patterns/dk_privacy_cover.dart';
import 'package:app_pdf/providers/privacy_providers.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app-switcher privacy cover (DK-0234).
void main() {
  final secure = <bool>[];
  setUp(() {
    secure.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PrivacyChannel.channel, (call) async {
          if (call.method == 'setSecure') secure.add(call.arguments as bool);
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PrivacyChannel.channel, null);
  });

  Future<ProviderContainer> pump(WidgetTester tester, {Widget? body}) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dokuloTheme(DkTokens.light),
          builder: (context, child) => DkPrivacyCover(child: child!),
          home: body ?? const Text('statement.pdf'),
        ),
      ),
    );
    return container;
  }

  Future<void> lifecycle(WidgetTester tester, AppLifecycleState s) async {
    tester.binding.handleAppLifecycleStateChanged(s);
    await tester.pump();
  }

  testWidgets('Hide previews on: in the app switcher the symbol on '
      'color.background covers the app; back in front, the app shows', (
    tester,
  ) async {
    final container = await pump(tester);
    container.read(hidePreviewsProvider.notifier).set(true);
    await tester.pump();
    expect(find.byType(DkLogo), findsNothing, reason: 'in front: no cover');

    await lifecycle(tester, AppLifecycleState.inactive);
    expect(find.byType(DkLogo), findsOneWidget);
    final box = tester.widget<ColoredBox>(
      find.ancestor(of: find.byType(DkLogo), matching: find.byType(ColoredBox)),
    );
    expect(box.color, DkTokens.light.color.background);

    await lifecycle(tester, AppLifecycleState.resumed);
    expect(find.byType(DkLogo), findsNothing);
  });

  testWidgets('nothing to hide: the app switcher shows the app, and '
      'FLAG_SECURE stays off (screenshots allowed)', (tester) async {
    await pump(tester);
    await lifecycle(tester, AppLifecycleState.inactive);
    expect(find.byType(DkLogo), findsNothing);
    expect(secure, [false]);
    await lifecycle(tester, AppLifecycleState.resumed);
  });

  testWidgets('FLAG_SECURE only while locked content is open', (tester) async {
    final container = await pump(tester);
    expect(secure, [false]);
    final locked = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: locked,
          builder: (context, child) => DkPrivacyCover(child: child!),
          theme: dokuloTheme(DkTokens.light),
          home: const Text('Files'),
        ),
      ),
    );
    locked.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const DkLockedContent(child: Text('Locked folder')),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(privacyCoverProvider), isTrue);
    expect(secure.last, isTrue);

    locked.currentState!.pop();
    await tester.pumpAndSettle();
    expect(container.read(privacyCoverProvider), isFalse);
    expect(secure.last, isFalse);
  });
}
