import 'package:app_pdf/providers/onboarding_providers.dart';

/// Starts a test past onboarding (DK-0238): the app opens on Home, as after
/// the first launch, without the file system.
final onboardingSeen = onboardingDoneProvider.overrideWith(_Seen.new);

class _Seen extends OnboardingDone {
  @override
  Future<bool> build() async => true;
}
