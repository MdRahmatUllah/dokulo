import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../components/dk_logo.dart';
import '../../routes/routes.dart';
import '../../theme/dk_tokens.dart';

/// Launch (DK-0073; UI spec §13): the app's first frame is the native
/// splash again: `color.background` with the symbol, 72 dp, centred, no
/// text, no spinner. So the hand-over from the platform shows no jump; then
/// it goes on to Home.
class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> {
  @override
  void initState() {
    super.initState();
    // After the first frame is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(Routes.home);
    });
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.tokens.color.background,
    child: const Center(child: DkLogo.symbol()),
  );
}
