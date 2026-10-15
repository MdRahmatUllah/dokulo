import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/dk_logo.dart';
import '../../providers/onboarding_providers.dart';
import '../../routes/routes.dart';
import '../../theme/dk_tokens.dart';

/// Launch (DK-0073; UI spec §13): the app's first frame is the native
/// splash again: `color.background` with the symbol, 72 dp, centred, no
/// text, no spinner. So the hand-over from the platform shows no jump; then
/// it goes on to Home, or to onboarding on the first launch (DK-0238).
class LaunchScreen extends ConsumerStatefulWidget {
  const LaunchScreen({super.key});

  @override
  ConsumerState<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends ConsumerState<LaunchScreen> {
  @override
  void initState() {
    super.initState();
    // After the first frame is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final seen = await ref.read(onboardingDoneProvider.future);
      if (mounted) context.go(seen ? Routes.home : Routes.welcome);
    });
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.tokens.color.background,
    child: const Center(child: DkLogo.symbol()),
  );
}
