import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../catalogue/catalogue.dart';
import '../components/dk_scan_button.dart';
import '../components/motion/dk_transition_motion.dart';
import '../screens/files/files_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/launch/launch_screen.dart';
import '../screens/locked/locked_folder_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/placeholder_screen.dart';
import '../screens/s1_scanner/camera_permission_gate.dart';
import '../screens/t2_tool/tool_options_screen.dart';
import '../screens/t3_result/tool_result_screen.dart';
import '../screens/v1_viewer/viewer_screen.dart';
import '../tools/tool_catalogue.dart';
import '../tools/tool_definition.dart';
import 'app_shell.dart';
import 'bottom_chrome.dart';
import 'link_error.dart';

part 'routes.g.dart';

/// Every route, by screen ID. The table with its rules is in
/// docs/Developer guide.md §3. Sheets (A1, X1, X2, X3) are not routes.
abstract final class Routes {
  static const launch = '/launch'; // the first frame, as the splash
  static const welcome = '/welcome'; // onboarding
  static const home = '/home'; // H1
  static const tools = '/tools'; // T1
  static const files = '/files'; // F1
  static const filesSearch = '/files?search=1'; // F1, the search focused
  static const lockedFolder = '/files/locked'; // F2
  static String folder(int id) => '/files/folder/$id'; // a folder in F1
  static const trash = '/files/trash'; // Recently deleted
  static const me = '/me'; // M1
  static const models = '/me/models'; // M2
  static String settings(String page) => '/me/settings/$page'; // M3
  static const scan = '/scan'; // S1

  /// S1 in a mode from the Scan button's menu.
  static String scanIn(DkScanMode mode) => '/scan?mode=${mode.name}';
  static const scanReview = '/scan/review'; // S2

  /// Import photos (the Scan popover): S2 opens the photo picker first.
  static const scanImport = '/scan/review?source=photos';

  /// T2; [files] (row ids) are its input, in order (X1, a share, a widget,
  /// an extension): `?file=` once per file. [chained]: the input is the
  /// result before it (a Next chip, DK-0386).
  static String tool(
    String toolId, {
    List<String> files = const [],
    bool chained = false,
  }) {
    final query = {
      if (files.isNotEmpty) 'file': files,
      if (chained) 'chain': '1',
    };
    return Uri(
      path: '/tool/$toolId',
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }

  static String toolResult(String toolId) => '/tool/$toolId/result'; // T3
  /// V1; `edit: true` opens it in edit mode (V2).
  static String viewer(String fileId, {bool edit = false}) =>
      '/viewer/$fileId${edit ? '?mode=edit' : ''}';
  static String organize(String fileId) => '/organize/$fileId'; // P1

  /// A running job's progress (X2) over Home: a notification's tap.
  static String job(int jobId) => '/job/$jobId';

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
    // A link to no route says so (DK-0236), instead of go_router's page.
    errorPageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: const _HomeUnderneath(child: LinkErrorScreen()),
    ),
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(routes: [_screen(Routes.tools, 'T1')]),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.files,
                builder: (context, state) => const FilesScreen(),
                routes: [
                  // The folder screen (DK-0262) and the trash (DK-0278).
                  GoRoute(
                    path: 'folder/:id',
                    builder: (context, state) => FilesScreen(
                      // A malformed id finds no folder: the screen is empty.
                      folder: int.tryParse(state.pathParameters['id']!) ?? -1,
                    ),
                  ),
                  _screen('trash', 'Recently deleted'),
                ],
              ),
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
                      child: PlaceholderScreen(
                        'M3',
                        detail: state.pathParameters['page']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // F2: full-screen pages, no tab bar (UI spec §16.6, DK-0283).
      fullScreen(Routes.lockedFolder, (_) => const LockedFolderScreen()),
      fullScreen(Routes.welcome, (_) => const OnboardingScreen()),
      // The scanner slides up and back down (UI spec §13.4).
      GoRoute(
        path: Routes.scan,
        parentNavigatorKey: root,
        pageBuilder: (context, s) => dkSlideUpPage(
          context,
          key: s.pageKey,
          child: _HomeUnderneath(
            child: _scanner(s.uri.queryParameters['mode'] ?? ''),
          ),
        ),
        routes: [
          fullScreen(
            'review',
            (s) => PlaceholderScreen(
              'S2',
              detail: s.uri.queryParameters['source'] ?? '',
            ),
          ),
        ],
      ),
      fullScreen(
        '/tool/:toolId',
        (s) {
          final toolId = s.pathParameters['toolId']!;
          // A link to a tool this version doesn't have (DK-0236).
          if (!ToolCatalogue.all.any((t) => t.id == toolId)) {
            return const LinkErrorScreen();
          }
          final files = s.uri.queryParametersAll['file'] ?? const [];
          final screen = ToolOptionsScreen(
            definition: ToolDefinitions.of(toolId),
            fileIds: [for (final f in files) int.tryParse(f) ?? -1],
            chained: s.uri.queryParameters['chain'] == '1',
          );
          return files.isEmpty
              ? screen
              : LinkedFileGate(fileIds: files, child: screen);
        },
        routes: [
          // The result cross-fades in after the progress (UI spec §13.4).
          GoRoute(
            path: 'result',
            parentNavigatorKey: root,
            pageBuilder: (context, s) => dkFadePage(
              context,
              key: s.pageKey,
              child: _HomeUnderneath(
                child: ToolResultScreen(toolId: s.pathParameters['toolId']!),
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
      // A job link opens Home with the job's progress sheet; a job that has
      // ended says so in a toast (DK-0236).
      GoRoute(
        path: '/job/:jobId',
        redirect: (context, s) {
          final id = int.tryParse(s.pathParameters['jobId']!);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final context = root.currentContext;
            if (context != null && context.mounted) {
              showJobProgress(context, id ?? -1);
            }
          });
          return Routes.home;
        },
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
Widget _scanner(String mode) {
  final camera = PlaceholderScreen('S1', detail: mode);
  if (mode == DkScanMode.importPhotos.name) return camera;
  return Builder(
    builder: (context) => CameraPermissionGate(
      camera: (_) => camera,
      onClose: () => context.canPop() ? context.pop() : context.go(Routes.home),
      // As the Scan button's Import photos: S2's picker (DK-0230).
      onImport: () => context.pushReplacement(Routes.scanImport),
    ),
  );
}
