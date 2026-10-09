import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../catalogue/catalogue.dart';
import '../components/dk_scan_button.dart';
import '../components/motion/dk_transition_motion.dart';
import '../screens/launch/launch_screen.dart';
import '../screens/m3_settings/scanning_settings_screen.dart';
import '../screens/placeholder_screen.dart';
import '../screens/s1_scanner/camera_permission_gate.dart';
import '../screens/s1_scanner/s1_screen.dart';
import '../screens/s2_review/s2_screen.dart';
import '../screens/v1_viewer/viewer_screen.dart';
import 'app_shell.dart';

part 'routes.g.dart';

/// Every route, by screen ID. The table with its rules is in
/// docs/Developer guide.md §3. Sheets (A1, X1, X2, X3) are not routes.
abstract final class Routes {
  static const launch = '/launch'; // the first frame, as the splash
  static const welcome = '/welcome'; // onboarding
  static const home = '/home'; // H1
  static const tools = '/tools'; // T1
  static const files = '/files'; // F1
  static const lockedFolder = '/files/locked'; // F2
  static const me = '/me'; // M1
  static const models = '/me/models'; // M2
  static String settings(String page) => '/me/settings/$page'; // M3
  static const scan = '/scan'; // S1

  /// S1 in a mode from the Scan button's menu.
  static String scanIn(DkScanMode mode) => '/scan?mode=${mode.name}';
  static const scanReview = '/scan/review'; // S2

  /// S1 taking page [index] again for S2 (DK-0350).
  static String scanRetake(int index) => '/scan?retake=$index';

  /// Import photos (the Scan popover): S2 opens the photo picker first.
  static const scanImport = '/scan/review?source=photos';
  static String tool(String toolId) => '/tool/$toolId'; // T2
  static String toolResult(String toolId) => '/tool/$toolId/result'; // T3
  /// V1; `edit: true` opens it in edit mode (V2).
  static String viewer(String fileId, {bool edit = false}) =>
      '/viewer/$fileId${edit ? '?mode=edit' : ''}';
  static String organize(String fileId) => '/organize/$fileId'; // P1

  /// The component catalogue (`lib/catalogue/`): debug builds only.
  static const catalogue = '/dev/catalogue';
}

GoRoute _screen(String path, String id, {List<RouteBase> routes = const []}) =>
    GoRoute(
      path: path,
      // A MaterialPage, so a push takes the theme's transition (UI spec
      // §13.4, DkPageTransitionsBuilder); go_router's own choice depends on
      // the app type it finds.
      pageBuilder: (context, state) =>
          MaterialPage(key: state.pageKey, child: PlaceholderScreen(id)),
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
    // A MaterialPage, so it takes the theme's push transition (§13.4).
    pageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: _HomeUnderneath(child: builder(state)),
    ),
    routes: routes,
  );

  return GoRouter(
    navigatorKey: root,
    initialLocation: initialLocation,
    routes: [
      // The app starts here (DK-0073): no transition, the splash again.
      GoRoute(
        path: Routes.launch,
        parentNavigatorKey: root,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LaunchScreen()),
      ),
      StatefulShellRoute(
        builder: (context, state, shell) => AppShell(shell),
        // Tabs cross-fade (UI spec §13.4); each keeps its stack.
        navigatorContainerBuilder: (context, shell, children) =>
            DkFadingBranches(
              currentIndex: shell.currentIndex,
              children: children,
            ),
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
                    pageBuilder: (context, state) => MaterialPage(
                      key: state.pageKey,
                      child: switch (state.pathParameters['page']!) {
                        'scanning' => const ScanningSettingsScreen(),
                        final page => PlaceholderScreen('M3', detail: page),
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      fullScreen(Routes.welcome, (_) => const PlaceholderScreen('Onboarding')),
      // The scanner slides up and back down (UI spec §13.4).
      GoRoute(
        path: Routes.scan,
        parentNavigatorKey: root,
        pageBuilder: (context, s) => dkSlideUpPage(
          context,
          key: s.pageKey,
          child: _HomeUnderneath(
            child: _scanner(
              s.uri.queryParameters['mode'] ?? '',
              retake: int.tryParse(s.uri.queryParameters['retake'] ?? ''),
            ),
          ),
        ),
        routes: [
          fullScreen(
            'review',
            (s) => Builder(
              builder: (context) => S2Screen(
                // The photo picker first (DK-0351).
                importOnOpen: s.uri.queryParameters['source'] == 'photos',
                onAddPages: () =>
                    context.canPop() ? context.pop() : context.go(Routes.scan),
                onDiscard: () => context.go(Routes.home),
                onRetake: (i) => context.push(Routes.scanRetake(i)),
              ),
            ),
          ),
        ],
      ),
      fullScreen(
        '/tool/:toolId',
        (s) => PlaceholderScreen('T2', detail: s.pathParameters['toolId']!),
        routes: [
          // The result cross-fades in after the progress (UI spec §13.4).
          GoRoute(
            path: 'result',
            parentNavigatorKey: root,
            pageBuilder: (context, s) => dkFadePage(
              context,
              key: s.pageKey,
              child: _HomeUnderneath(
                child: PlaceholderScreen(
                  'T3',
                  detail: s.pathParameters['toolId']!,
                ),
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/viewer/:fileId',
        parentNavigatorKey: root,
        // The file's thumbnail expands into the first page (DK-0046).
        pageBuilder: (context, s) => dkViewerPage(
          context,
          key: s.pageKey,
          child: _HomeUnderneath(
            child: s.uri.queryParameters['mode'] == 'edit'
                ? PlaceholderScreen('V2', detail: s.pathParameters['fileId']!)
                // A file id is its row id; a malformed one finds no file.
                : ViewerScreen(
                    fileId: int.tryParse(s.pathParameters['fileId']!) ?? -1,
                  ),
          ),
        ),
      ),
      fullScreen(
        '/organize/:fileId',
        (s) => PlaceholderScreen('P1', detail: s.pathParameters['fileId']!),
      ),
      // The component catalogue: debug builds only (kDebugMode is a
      // constant, so a release build doesn't contain it).
      if (kDebugMode)
        fullScreen(
          Routes.catalogue,
          (_) => const CatalogueScreen(),
          routes: [
            fullScreen(
              ':name',
              (s) => CatalogueEntryScreen(s.pathParameters['name']!),
            ),
          ],
        ),
    ],
  );
}

/// The app's router. Kept alive: it holds every tab's navigation stack.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final router = buildRouter(initialLocation: Routes.launch);
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

/// S1 behind its camera permission (DK-0342). Importing photos needs no
/// camera; every other mode asks for it first.
Widget _scanner(String mode, {int? retake}) {
  if (mode == DkScanMode.importPhotos.name) {
    return PlaceholderScreen('S1', detail: mode);
  }
  return Builder(
    builder: (context) {
      void close() =>
          context.canPop() ? context.pop() : context.go(Routes.home);
      // As the Scan button's Import photos: S2's picker (DK-0230).
      void import() => context.pushReplacement(Routes.scanImport);
      return CameraPermissionGate(
        camera: (_) => S1Screen(
          initialMode: DkScanMode.values.asNameMap()[mode],
          retake: retake,
          // Back to S2, the page replaced.
          onRetaken: () => context.pop(),
          onClose: close,
          onImport: import,
          onReview: () => context.push(Routes.scanReview),
          onSettings: () => context.push(Routes.settings('scanning')),
        ),
        onClose: close,
        onImport: import,
      );
    },
  );
}
