import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../screens/placeholder_screen.dart';
import 'app_shell.dart';

part 'routes.g.dart';

/// Every route, by screen ID. The table with its rules is in
/// docs/Developer guide.md §3. Sheets (A1, X1, X2, X3) are not routes.
abstract final class Routes {
  static const welcome = '/welcome'; // onboarding
  static const home = '/home'; // H1
  static const tools = '/tools'; // T1
  static const files = '/files'; // F1
  static const lockedFolder = '/files/locked'; // F2
  static const me = '/me'; // M1
  static const models = '/me/models'; // M2
  static String settings(String page) => '/me/settings/$page'; // M3
  static const scan = '/scan'; // S1
  static const scanReview = '/scan/review'; // S2
  static String tool(String toolId) => '/tool/$toolId'; // T2
  static String toolResult(String toolId) => '/tool/$toolId/result'; // T3
  /// V1; `edit: true` opens it in edit mode (V2).
  static String viewer(String fileId, {bool edit = false}) =>
      '/viewer/$fileId${edit ? '?mode=edit' : ''}';
  static String organize(String fileId) => '/organize/$fileId'; // P1
}

GoRoute _screen(String path, String id, {List<RouteBase> routes = const []}) =>
    GoRoute(
      path: path,
      builder: (context, state) => PlaceholderScreen(id),
      routes: routes,
    );

/// Builds the router; `initialLocation` is for tests (a cold start at any
/// route), the platform's deep link overrides it in the app.
GoRouter buildRouter({String initialLocation = Routes.home}) {
  final root = GlobalKey<NavigatorState>(debugLabel: 'root');

  /// Full-screen routes sit on the root navigator, above the shell, so the
  /// tab bar is hidden and back returns to the tab they were pushed from.
  GoRoute fullScreen(
    String path,
    Widget Function(GoRouterState state) builder, {
    List<RouteBase> routes = const [],
  }) => GoRoute(
    path: path,
    parentNavigatorKey: root,
    builder: (context, state) => _HomeUnderneath(child: builder(state)),
    routes: routes,
  );

  return GoRouter(
    navigatorKey: root,
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell),
        branches: [
          StatefulShellBranch(routes: [_screen(Routes.home, 'H1')]),
          StatefulShellBranch(routes: [_screen(Routes.tools, 'T1')]),
          StatefulShellBranch(
            routes: [
              _screen(Routes.files, 'F1', routes: [_screen('locked', 'F2')]),
            ],
          ),
          StatefulShellBranch(
            routes: [
              _screen(
                Routes.me,
                'M1',
                routes: [
                  _screen('models', 'M2'),
                  GoRoute(
                    path: 'settings/:page',
                    builder: (context, state) => PlaceholderScreen(
                      'M3',
                      detail: state.pathParameters['page']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      fullScreen(Routes.welcome, (_) => const PlaceholderScreen('Onboarding')),
      fullScreen(
        Routes.scan,
        (_) => const PlaceholderScreen('S1'),
        routes: [fullScreen('review', (_) => const PlaceholderScreen('S2'))],
      ),
      fullScreen(
        '/tool/:toolId',
        (s) => PlaceholderScreen('T2', detail: s.pathParameters['toolId']!),
        routes: [
          fullScreen(
            'result',
            (s) => PlaceholderScreen('T3', detail: s.pathParameters['toolId']!),
          ),
        ],
      ),
      fullScreen(
        '/viewer/:fileId',
        (s) => PlaceholderScreen(
          s.uri.queryParameters['mode'] == 'edit' ? 'V2' : 'V1',
          detail: s.pathParameters['fileId']!,
        ),
      ),
      fullScreen(
        '/organize/:fileId',
        (s) => PlaceholderScreen('P1', detail: s.pathParameters['fileId']!),
      ),
    ],
  );
}

/// The app's router. Kept alive: it holds every tab's navigation stack.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
}

/// Back from a full-screen page that a deep link opened (nothing beneath it)
/// goes to Home instead of leaving the app; pushed from a tab, it pops as
/// usual (DK-1041).
class _HomeUnderneath extends StatelessWidget {
  const _HomeUnderneath({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    return PopScope(
      canPop: router.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) router.go(Routes.home);
      },
      child: child,
    );
  }
}
