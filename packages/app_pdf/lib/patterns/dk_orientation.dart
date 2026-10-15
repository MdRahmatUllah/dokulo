import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routes/routes.dart';

/// Which way a screen may turn (DK-0656; UI spec §30 "Phone landscape"):
/// on a phone only the Viewer, the Scanner, Compare and Translate turn;
/// everything else stays portrait. Tablets turn everywhere. The signature
/// pad asks for landscape itself and hands back to this on close.
List<DeviceOrientation> orientationsFor(
  String location, {
  required bool phone,
}) {
  const any = <DeviceOrientation>[]; // the platform's (and Info.plist's) set
  if (!phone) return any;
  final path = Uri.parse(location).path;
  const turns = ['/viewer', '/scan', '/tool/compare', '/tool/translate'];
  return turns.any((p) => path == p || path.startsWith('$p/'))
      ? any
      : const [DeviceOrientation.portraitUp];
}

/// Applies [orientationsFor] to the route on top whenever it changes.
class DkOrientation extends ConsumerStatefulWidget {
  const DkOrientation({super.key, required this.child});

  final Widget child;

  /// The rule applied last: what the signature pad gives back on close.
  static List<DeviceOrientation> current = const [];

  @override
  ConsumerState<DkOrientation> createState() => _DkOrientationState();
}

class _DkOrientationState extends ConsumerState<DkOrientation> {
  List<DeviceOrientation>? _applied;

  @override
  void initState() {
    super.initState();
    ref.read(appRouterProvider).routerDelegate.addListener(_apply);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apply(); // the first route, and a phone/tablet change
  }

  @override
  void dispose() {
    ref.read(appRouterProvider).routerDelegate.removeListener(_apply);
    super.dispose();
  }

  void _apply() {
    if (!mounted) return;
    final router = ref.read(appRouterProvider);
    final want = orientationsFor(
      router.routerDelegate.currentConfiguration.uri.toString(),
      // shortestSide: a phone stays a phone when it turns.
      phone: MediaQuery.sizeOf(context).shortestSide < 600,
    );
    if (_applied != null && listEquals(_applied!, want)) return;
    _applied = DkOrientation.current = want;
    SystemChrome.setPreferredOrientations(want);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
