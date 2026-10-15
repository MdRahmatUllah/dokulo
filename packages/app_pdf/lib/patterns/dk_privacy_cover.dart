import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/dk_logo.dart';
import '../providers/privacy_providers.dart';
import '../theme/dk_tokens.dart';

/// The app-switcher privacy cover (UI spec §13.3; DK-0234): while
/// [privacyCoverProvider] holds and the app isn't in front (inactive,
/// hidden, paused), `color.background` with the symbol centred covers
/// everything, as the launch screen. It also sets Android's FLAG_SECURE for
/// as long as the cover is needed. The app root wraps the whole app in it.
class DkPrivacyCover extends ConsumerStatefulWidget {
  const DkPrivacyCover({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DkPrivacyCover> createState() => _DkPrivacyCoverState();
}

class _DkPrivacyCoverState extends ConsumerState<DkPrivacyCover>
    with WidgetsBindingObserver {
  var _inFront = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _inFront = state == null || state == AppLifecycleState.resumed;
    ref.listenManual(
      privacyCoverProvider,
      (_, on) => PrivacyChannel.setSecure(on),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      setState(() => _inFront = state == AppLifecycleState.resumed);

  @override
  Widget build(BuildContext context) {
    final covered = !_inFront && ref.watch(privacyCoverProvider);
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        if (covered)
          Positioned.fill(
            child: ColoredBox(
              color: context.tokens.color.background,
              child: const Center(child: DkLogo.symbol()),
            ),
          ),
      ],
    );
  }
}

/// Wrap a screen that shows locked-folder content: while it's open, the app
/// switcher shows the privacy cover (DK-0234).
class DkLockedContent extends ConsumerStatefulWidget {
  const DkLockedContent({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DkLockedContent> createState() => _DkLockedContentState();
}

class _DkLockedContentState extends ConsumerState<DkLockedContent> {
  late final LockedContentOpen _open;

  @override
  void initState() {
    super.initState();
    _open = ref.read(lockedContentOpenProvider.notifier);
    // Not during build: the cover listens to the count.
    Future.microtask(_open.enter);
  }

  @override
  void dispose() {
    Future.microtask(_open.leave);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
