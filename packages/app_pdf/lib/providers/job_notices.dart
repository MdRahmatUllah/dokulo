import 'dart:async';
import 'dart:io';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:doc_tools/doc_tools.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../l10n/app_localizations.dart';
import '../l10n/formats.dart';
import '../routes/routes.dart';
import '../tools/tool_catalogue.dart';
import 'language_providers.dart';

part 'job_notices.g.dart';

/// A local notice on the phone (UI spec §25.1; DK-0587): no push server.
/// Tapping it opens [link], a route, through `dokulo://open<link>`, the
/// app's deep link, so it works from a cold start too.
class JobNotice {
  const JobNotice({
    required this.id,
    required this.channel,
    required this.channelName,
    required this.title,
    required this.body,
    required this.link,
  });

  /// One notice per job: a second one for the same id replaces it.
  final int id;

  /// The Android channel: `jobs` or `downloads`.
  final String channel;
  final String channelName;
  final String title;
  final String body;
  final String link;

  Map<String, Object> toMap() => {
    'id': id,
    'channel': channel,
    'channelName': channelName,
    'title': title,
    'body': body,
    'link': 'dokulo://open$link',
  };
}

/// Shows notices, behind an interface so tests can fake it.
abstract interface class JobNotices {
  Future<void> show(JobNotice notice);
}

/// `MainActivity.kt` (NotificationManager, the small icon `ic_stat_dokulo`)
/// and `AppDelegate.swift` (UNUserNotificationCenter), on the permission's
/// channel `dokulo/notifications`. Without permission the system drops it.
class PlatformJobNotices implements JobNotices {
  const PlatformJobNotices();

  @override
  Future<void> show(JobNotice notice) async {
    try {
      await const MethodChannel('dokulo/notifications')
          .invokeMethod<void>('show', notice.toMap());
    } on MissingPluginException {
      // Tests and desktop: no notices.
    }
  }
}

@Riverpod(keepAlive: true)
JobNotices jobNotices(Ref ref) => const PlatformJobNotices();

/// Whether Dokulo is off screen: only then does a job's end get a notice;
/// on screen, T3 or the mini bar shows it.
@Riverpod(keepAlive: true)
bool Function() appInBackground(Ref ref) =>
    () => switch (WidgetsBinding.instance.lifecycleState) {
      AppLifecycleState.resumed || null => false,
      _ => true,
    };

/// [JobHooks.onFinished] / [JobHooks.onFailed] (a cancel calls neither): the
/// notice, if Dokulo is in the background.
void noticeIfAway(Ref ref, ToolRun run, {JobOutput? output, Object? error}) {
  if (!ref.read(appInBackgroundProvider)()) return;
  unawaited(
    ref
        .read(jobNoticesProvider)
        .show(
          jobEndedNotice(
            ref,
            jobId: run.id,
            toolId: run.toolId,
            output: output,
            failed: error != null,
          ),
        ),
  );
}

/// The notice for a job that ended: "Compress PDF finished" with the file
/// and its size, or "Couldn't finish Merge PDF".
JobNotice jobEndedNotice(
  Ref ref, {
  required int jobId,
  required String toolId,
  JobOutput? output,
  bool failed = false,
}) {
  final l = appL10n(ref);
  final tool = ToolCatalogue.of(toolId).name(l);
  return JobNotice(
    id: jobId,
    channel: 'jobs',
    channelName: l.notice_channel_jobs,
    title: failed || output == null
        ? l.notice_job_failed(tool)
        : l.notice_job_done(tool),
    body: failed || output == null
        ? l.notice_job_failed_body
        : _what(output, l),
    link: Routes.job(jobId),
  );
}

/// The app's language outside a widget (notices, shortcuts): the app's,
/// else the phone's (English when Dokulo doesn't speak it).
AppLocalizations appL10n(Ref ref) {
  final locale =
      ref.read(appLanguageSettingProvider).locale ??
      PlatformDispatcher.instance.locale;
  return lookupAppLocalizations(
    AppLocalizations.supportedLocales.any(
          (s) => s.languageCode == locale.languageCode,
        )
        ? locale
        : const Locale('en'),
  );
}

/// The photo finder's notice's id: job ids start at 1, so it never
/// replaces a job's notice (and a later scan's replaces this one).
const photoFinderNoticeId = 0;

/// Photo finder done (§25.1; DK-0592): "Found 37 documents in your photos",
/// "Tap to review", opening the results. Only in the background, and only
/// when it found something.
void photoFinderNoticeIfAway(Ref ref, int found) {
  if (found == 0 || !ref.read(appInBackgroundProvider)()) return;
  final l = appL10n(ref);
  unawaited(
    ref
        .read(jobNoticesProvider)
        .show(
          JobNotice(
            id: photoFinderNoticeId,
            channel: 'jobs',
            channelName: l.notice_channel_jobs,
            title: l.notice_photos_found(found),
            body: l.notice_photos_body,
            link: Routes.photos,
          ),
        ),
  );
}

/// "Mietvertrag.pdf · 1.9 MB", or "3 files".
String _what(JobOutput output, AppLocalizations l) => switch (output) {
  OneFile(:final path) => [
    path.split(RegExp(r'[\\/]')).last,
    if (File(path).existsSync())
      formatBytes(File(path).lengthSync(), l.localeName),
  ].join(' · '),
  ManyFiles(:final paths) => l.notice_files(paths.length),
  TextOutput() => '',
};
