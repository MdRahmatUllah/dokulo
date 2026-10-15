import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../components/dk_file_card.dart';
import '../providers/database_providers.dart';
import '../providers/file_providers.dart';
import '../providers/files_providers.dart';
import '../routes/routes.dart';
import '../tools/tool_inputs.dart';
import 'dk_tool_picker.dart';

/// Files shared to Dokulo or opened with it (DK-0235), already copied into
/// the app's cache by the platform: [view] for "Open with" (Android's VIEW,
/// iOS's open in place), otherwise a share.
typedef IncomingBatch = ({bool view, List<String> paths});

/// The platform side, channel `dokulo/incoming`: the batches it holds when
/// listened to, then each one it says is "available". A cold start's share
/// waits there until Dart takes it. Tests override it.
final incomingFilesProvider = Provider<Stream<IncomingBatch>>((ref) {
  const channel = MethodChannel('dokulo/incoming');
  final out = StreamController<IncomingBatch>();
  Future<void> take() async {
    try {
      final batches = await channel.invokeListMethod<Map>('take') ?? const [];
      for (final b in batches) {
        out.add((
          view: b['action'] == 'view',
          paths: [...(b['paths'] as List).cast<String>()],
        ));
      }
    } on MissingPluginException {
      // No platform side (tests, desktop): nothing comes in.
    }
  }

  channel.setMethodCallHandler((call) async {
    if (call.method == 'available') await take();
  });
  out.onListen = take;
  ref.onDispose(() {
    channel.setMethodCallHandler(null);
    out.close();
  });
  return out.stream;
});

/// Opens what came in (DK-0235): each file copied into Dokulo's folder and
/// indexed, the cache copy deleted; then "Open with" on one PDF opens V1,
/// anything else X1 with the files chosen (several files: only the tools
/// that take them). Waits until the app is past the launch screen and
/// onboarding.
Future<void> openIncoming(
  ProviderContainer ref,
  GoRouter router,
  IncomingBatch batch,
) async {
  final db = ref.read(appDatabaseProvider);
  final store = await ref.read(fileStoreProvider.future);
  final ids = <int>[];
  for (final path in batch.paths) {
    final copy = File(path);
    try {
      ids.add(await store.importToUserFolder(db, copy));
      await copy.delete();
    } on FileSystemException {
      // ponytail: an unreadable file is left out; say so when it happens.
    }
  }
  if (ids.isEmpty) return;
  await _pastLaunch(router);
  final files = [
    for (final id in ids)
      await (db.select(db.files)..where((f) => f.id.equals(id))).getSingle(),
  ];
  if (batch.view &&
      files.length == 1 &&
      ToolInput.kindOf(files.single.path) == DkFileKind.pdf) {
    await recordOpened(db, files.single.id);
    await router.push(Routes.viewer('${files.single.id}'));
    return;
  }
  final context = router.routerDelegate.navigatorKey.currentContext;
  if (context != null && context.mounted) await showToolPicker(context, files);
}

Future<void> _pastLaunch(GoRouter router) async {
  bool ready() =>
      !{Routes.launch, Routes.welcome}.contains(router.state.uri.path);
  if (ready()) return;
  final done = Completer<void>();
  void check() {
    if (ready() && !done.isCompleted) done.complete();
  }

  router.routerDelegate.addListener(check);
  await done.future;
  router.routerDelegate.removeListener(check);
}

/// Listens for incoming files while the app runs and opens each batch in
/// turn ([openIncoming]).
class DkIncomingFiles extends ConsumerStatefulWidget {
  const DkIncomingFiles({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DkIncomingFiles> createState() => _DkIncomingFilesState();
}

class _DkIncomingFilesState extends ConsumerState<DkIncomingFiles> {
  StreamSubscription<IncomingBatch>? _sub;
  var _queue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    final container = ProviderScope.containerOf(context, listen: false);
    _sub = ref.read(incomingFilesProvider).listen((batch) {
      // One batch's failure (a full disk) doesn't stop the next.
      _queue = _queue
          .then((_) {
            if (!mounted) return null;
            return openIncoming(
              container,
              container.read(appRouterProvider),
              batch,
            );
          })
          .onError<Object>(
            (e, s) => FlutterError.reportError(
              FlutterErrorDetails(exception: e, stack: s),
            ),
          );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
