import 'dart:async';

import 'package:doc_core/doc_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/dk_action_sheet.dart';
import '../../components/dk_banner.dart';
import '../../components/dk_button.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_file_card.dart';
import '../../components/dk_illustration.dart';
import '../../components/dk_pdf_canvas.dart';
import '../../components/dk_pin_pad.dart';
import '../../components/dk_toast.dart';
import '../../components/dk_top_bar.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/formats.dart';
import '../../patterns/dk_undo.dart';
import '../../providers/database_providers.dart';
import '../../providers/file_providers.dart';
import '../../providers/files_providers.dart';
import '../../providers/locked_providers.dart';
import '../../routes/routes.dart';
import '../../theme/dk_tokens.dart';

/// Where F2 is in its flow (UI spec §16.6).
enum LockedStep {
  loading,
  intro,
  createPin,
  confirmPin,
  biometrics,
  unlock,
  open,
}

/// F2 · Locked folder (DK-0283..DK-0288): the first time, L1 intro → L2 PIN
/// → L3 the PIN again → L4 biometrics; after that the unlock screen, with
/// the biometric prompt on open. Unlocked, the folder's content; leaving it,
/// "Lock now" or a minute in the background locks it again.
class LockedFolderScreen extends ConsumerStatefulWidget {
  const LockedFolderScreen({super.key, this.moveIn = const []});

  /// Files to move in once the folder is open (DK-0289): "Move to locked
  /// folder" runs the setup or the unlock first, then the move (flow 6).
  final List<int> moveIn;

  /// How long the folder stays open in the background (DK-0288).
  static const autoLock = Duration(minutes: 1);

  @override
  ConsumerState<LockedFolderScreen> createState() => _LockedFolderState();
}

class _LockedFolderState extends ConsumerState<LockedFolderScreen> {
  var _step = LockedStep.loading;
  String? _firstPin, _error;
  var _errors = 0;
  var _moved = false;
  DateTime? _hiddenAt;
  late final AppLifecycleListener _lifecycle;

  LockedVault get _vault => ref.read(lockedVaultProvider);
  late final LockedSession _session = ref.read(lockedSessionProvider.notifier);

  @override
  void initState() {
    super.initState();
    _session; // read now: ref can't be used in dispose
    _lifecycle = AppLifecycleListener(
      onHide: () => _hiddenAt = DateTime.now(),
      onShow: () {
        final hidden = _hiddenAt;
        _hiddenAt = null;
        if (hidden != null &&
            DateTime.now().difference(hidden) >= LockedFolderScreen.autoLock) {
          _lock();
        }
      },
    );
    _start();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    // Leaving the folder locks it: no key, no decrypted thumbnails stay.
    // After the unmount: a provider can't change while the tree finalizes.
    Future.microtask(_session.lock);
    super.dispose();
  }

  Future<void> _start() async {
    if (ref.read(lockedSessionProvider) != null) return _go(LockedStep.open);
    if (!await _vault.hasPin) return _go(LockedStep.intro);
    _go(LockedStep.unlock);
    _tryBiometrics(); // the prompt on open
  }

  void _go(LockedStep step) {
    if (!mounted) return;
    setState(() => _step = step);
    if (step == LockedStep.open && !_moved && widget.moveIn.isNotEmpty) {
      _moved = true;
      _moveIn();
    }
  }

  /// Seals [LockedFolderScreen.moveIn] into the vault, with Undo.
  Future<void> _moveIn() async {
    final l = AppLocalizations.of(context);
    final cipher = ref.read(lockedSessionProvider);
    if (cipher == null) return;
    final db = ref.read(appDatabaseProvider);
    final store = await ref.read(lockedStoreProvider.future);
    final thumbs = await ref.read(thumbnailCacheProvider.future);
    final moved = <LockedEntry>[];
    for (final id in widget.moveIn) {
      final row = await (db.select(
        db.files,
      )..where((f) => f.id.equals(id))).getSingleOrNull();
      if (row == null) continue;
      // No picture of it may stay in the plain cache.
      await thumbs.forget(row.path, pages: row.pages);
      moved.add(await store.moveIn(db, id, cipher));
    }
    ref.invalidate(lockedFilesProvider);
    if (!mounted || moved.isEmpty) return;
    await showDkUndo(
      context,
      DkUndo.move,
      l.locked_moved_in(moved.length),
      onUndo: () async {
        final files = await ref.read(fileStoreProvider.future);
        for (final e in moved) {
          await store.moveOut(db, files, e.id, cipher, folder: e.fromFolder);
        }
        ref.invalidate(lockedFilesProvider);
      },
    );
  }

  void _fail(String message) => setState(() {
    _error = message;
    _errors++;
  });

  void _opened(LockedCipher cipher) {
    ref.read(lockedSessionProvider.notifier).open(cipher);
    _error = null;
    _go(LockedStep.open);
  }

  void _lock() {
    ref.read(lockedSessionProvider.notifier).lock();
    _error = null;
    _go(LockedStep.unlock);
  }

  Future<void> _tryBiometrics() async {
    final l = AppLocalizations.of(context);
    final cipher = await _vault.unlockWithBiometrics(l.locked_bio_reason);
    if (cipher != null && mounted) _opened(cipher);
  }

  void _created(String pin) {
    _firstPin = pin;
    _error = null;
    _go(LockedStep.confirmPin);
  }

  Future<void> _confirmed(String pin) async {
    final l = AppLocalizations.of(context);
    if (pin != _firstPin) {
      // Back to L2, its values cleared, with the dots shaking.
      _firstPin = null;
      _fail(l.locked_pin_mismatch);
      return _go(LockedStep.createPin);
    }
    await _vault.setPin(pin);
    final kind = await ref.read(biometricKindProvider.future);
    final result = await _vault.unlockWithPin(pin);
    if (!mounted || result is! PinUnlocked) return;
    ref.read(lockedSessionProvider.notifier).open(result.cipher);
    _error = null;
    _go(kind == null ? LockedStep.open : LockedStep.biometrics);
  }

  Future<void> _entered(String pin) async {
    final l = AppLocalizations.of(context);
    switch (await _vault.unlockWithPin(pin)) {
      case PinUnlocked(:final cipher):
        _opened(cipher);
      case PinWrong(:final wait):
        _fail(
          wait == Duration.zero
              ? l.locked_pin_wrong
              : l.locked_pin_wait(wait.inSeconds),
        );
      case PinThrottled(:final wait):
        _fail(l.locked_pin_wait(wait.inSeconds));
    }
  }

  void _leave() => context.canPop() ? context.pop() : context.go(Routes.files);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final kind = ref.watch(biometricKindProvider).value;
    final body = switch (_step) {
      LockedStep.loading => const SizedBox.shrink(),
      LockedStep.intro => _Intro(
        kind: kind,
        onSetUp: () => _go(LockedStep.createPin),
      ),
      LockedStep.createPin => _PinStep(
        title: l.locked_create_pin,
        error: _error,
        errorCount: _errors,
        onComplete: _created,
      ),
      LockedStep.confirmPin => _PinStep(
        title: l.locked_confirm_pin,
        onComplete: _confirmed,
      ),
      LockedStep.biometrics => _Biometrics(
        kind: kind ?? BiometricKind.fingerprint,
        onUse: () async {
          await _vault.enableBiometrics(l.locked_bio_reason);
          _go(LockedStep.open);
        },
        onNotNow: () => _go(LockedStep.open),
      ),
      LockedStep.unlock => _PinStep(
        title: l.locked_title,
        lockIcon: true,
        error: _error,
        errorCount: _errors,
        onComplete: _entered,
        kind: kind,
        onBiometric: _tryBiometrics,
      ),
      LockedStep.open => _Content(onLock: _lock, onBack: _leave),
    };
    if (_step == LockedStep.open) return body;
    return Scaffold(
      backgroundColor: t.color.background,
      appBar: DkTopBar(
        leading: _step == LockedStep.intro
            ? DkTopBarLeading.close
            : DkTopBarLeading.back,
        onLeading: switch (_step) {
          LockedStep.createPin => () => _go(LockedStep.intro),
          LockedStep.confirmPin => () {
            _firstPin = null;
            _go(LockedStep.createPin);
          },
          _ => _leave,
        },
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}

String _method(BiometricKind kind) => kind == BiometricKind.faceId
    ? 'Face ID'
    : 'Touch ID'; // l10n-ignore: Apple's names, the same in every language

/// L1: why the folder is safe, and what is lost with the PIN.
class _Intro extends StatelessWidget {
  const _Intro({required this.kind, required this.onSetUp});

  final BiometricKind? kind;
  final VoidCallback onSetUp;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final body = switch (kind) {
      null => l.locked_intro_body_pin,
      BiometricKind.fingerprint => l.locked_intro_body_fingerprint,
      final apple => l.locked_intro_body(_method(apple)),
    };
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              t.space.l,
              t.space.xxl + t.space.s,
              t.space.l,
              t.space.l,
            ),
            child: Column(
              children: [
                const DkIllustration(DkIllustrations.lockedFolderIntro),
                SizedBox(height: t.space.xl),
                Text(
                  l.locked_intro_title,
                  textAlign: TextAlign.center,
                  style: t.text.display.copyWith(color: t.color.textPrimary),
                ),
                SizedBox(height: t.space.s),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: t.space.s),
                  child: Text(
                    body,
                    textAlign: TextAlign.center,
                    style: t.text.bodyL.copyWith(color: t.color.textSecondary),
                  ),
                ),
                SizedBox(height: t.space.xl),
                DkBanner(
                  text: l.locked_intro_warning,
                  variant: DkBannerVariant.warning,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(t.space.l),
          child: DkButton(
            label: l.locked_set_up,
            size: DkButtonSize.large,
            expand: true,
            onPressed: onSetUp,
          ),
        ),
      ],
    );
  }
}

/// L2, L3 and the unlock screen: a title over the 6-digit pad.
class _PinStep extends StatelessWidget {
  const _PinStep({
    required this.title,
    required this.onComplete,
    this.error,
    this.errorCount = 0,
    this.lockIcon = false,
    this.kind,
    this.onBiometric,
  });

  final String title;
  final ValueChanged<String> onComplete;
  final String? error;
  final int errorCount;
  final bool lockIcon;
  final BiometricKind? kind;
  final VoidCallback? onBiometric;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final kind = this.kind;
    // The title and the dots near the top, the keypad 56 above the bottom
    // (the export); on a short screen or at large text it scrolls.
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                t.space.l,
                lockIcon ? t.space.s : t.space.xxxl + t.space.l,
                t.space.l,
                t.space.xxxl + t.space.s,
              ),
              child: Column(
                children: [
                  if (lockIcon) ...[
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: c.primaryContainer,
                        borderRadius: BorderRadius.circular(t.radius.l),
                      ),
                      // 40 dp, as the export: larger than DkIconSize goes.
                      child: Icon(
                        DkIcons.lock,
                        size: 40,
                        color: c.onPrimaryContainer,
                      ),
                    ),
                    SizedBox(height: t.space.l),
                  ],
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: t.text.titleM.copyWith(color: c.textPrimary),
                    ),
                  ),
                  SizedBox(height: t.space.l),
                  Expanded(
                    child: DkPinPad(
                      expand: true,
                      onComplete: onComplete,
                      error: error,
                      errorCount: errorCount,
                      onBiometric: kind == null ? null : onBiometric,
                      biometricIcon: kind == BiometricKind.faceId
                          ? DkIcons.faceId
                          : DkIcons.fingerprint,
                      biometricLabel: switch (kind) {
                        null => null,
                        BiometricKind.fingerprint =>
                          l.locked_bio_use_fingerprint,
                        final apple => l.locked_bio_use(_method(apple)),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// L4: open with biometrics from now on?
class _Biometrics extends StatelessWidget {
  const _Biometrics({
    required this.kind,
    required this.onUse,
    required this.onNotNow,
  });

  final BiometricKind kind;
  final VoidCallback onUse, onNotNow;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    final l = AppLocalizations.of(context);
    final face = kind == BiometricKind.faceId;
    final (title, use) = kind == BiometricKind.fingerprint
        ? (l.locked_bio_title_fingerprint, l.locked_bio_use_fingerprint)
        : (l.locked_bio_title(_method(kind)), l.locked_bio_use(_method(kind)));
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              t.space.l,
              t.space.xxxl * 2,
              t.space.l,
              t.space.l,
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: c.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    face ? DkIcons.faceId : DkIcons.fingerprint,
                    size: 40,
                    color: c.onPrimaryContainer,
                  ),
                ),
                SizedBox(height: t.space.xl),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: t.text.display.copyWith(color: c.textPrimary),
                ),
                SizedBox(height: t.space.s),
                Text(
                  face ? l.locked_bio_body_face : l.locked_bio_body_touch,
                  textAlign: TextAlign.center,
                  style: t.text.bodyL.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(t.space.l),
          child: Column(
            spacing: t.space.s,
            children: [
              DkButton(
                label: use,
                size: DkButtonSize.large,
                expand: true,
                onPressed: onUse,
              ),
              DkButton(
                label: l.common_not_now,
                variant: DkButtonVariant.tertiary,
                size: DkButtonSize.large,
                expand: true,
                onPressed: onNotNow,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Unlocked: the folder (its files come with DK-0289), "Lock now".
class _Content extends ConsumerWidget {
  const _Content({required this.onLock, required this.onBack});

  final VoidCallback onLock, onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final entries = ref.watch(lockedFilesProvider).value;
    return Scaffold(
      backgroundColor: t.color.background,
      appBar: DkTopBar(
        title: l.locked_title,
        titleIcon: DkIcons.lock,
        onLeading: onBack,
        actions: [
          DkTopBarAction(
            icon: DkIcons.lock,
            tooltip: l.locked_lock_now,
            onPressed: onLock,
          ),
        ],
      ),
      body: switch (entries) {
        null => const SizedBox.shrink(),
        [] => Center(
          child: Padding(
            padding: EdgeInsets.all(t.space.xl),
            child: Text(
              l.locked_empty,
              textAlign: TextAlign.center,
              style: t.text.bodyL.copyWith(color: t.color.textSecondary),
            ),
          ),
        ),
        final list => ListView(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                t.space.l,
                t.space.l,
                t.space.l,
                t.space.s,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l.files_files,
                        style: t.text.titleS.copyWith(
                          color: t.color.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    l.meta_files(list.length),
                    style: t.text.caption.copyWith(
                      color: t.color.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            for (final e in list) _LockedRow(e),
          ],
        ),
      },
    );
  }
}

/// A locked file: no thumbnail (nothing of it is rendered or cached while
/// it is sealed); a tap decrypts it for viewing, More moves it out.
class _LockedRow extends ConsumerWidget {
  const _LockedRow(this.entry);

  final LockedEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final meta = [
      formatBytes(entry.size, locale),
      if (entry.pages > 0) l.meta_pages(entry.pages),
      formatWhen(entry.added, l, locale),
    ].join(' · ');
    final page = ColoredBox(color: context.tokens.color.pageWhite);
    return DkFileCard(
      name: entry.name,
      meta: meta,
      thumbnail: page,
      onTap: () => _view(context, ref),
      onMore: () => showDkActionSheet(
        context,
        header: DkActionSheetHeader(
          thumbnail: page,
          name: entry.name,
          meta: meta,
        ),
        groups: [
          [
            DkAction(
              icon: DkIcons.lockOpen,
              label: l.locked_move_out,
              onTap: () => _moveOut(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _view(BuildContext context, WidgetRef ref) async {
    final cipher = ref.read(lockedSessionProvider);
    if (cipher == null) return;
    final store = await ref.read(lockedStoreProvider.future);
    final clear = await store.open(entry.id, cipher);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LockedViewer(name: entry.name, path: clear.path),
      ),
    );
    // Back from it: the decrypted copy goes at once.
    await store.closeAll();
  }

  Future<void> _moveOut(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final cipher = ref.read(lockedSessionProvider);
    if (cipher == null) return;
    final db = ref.read(appDatabaseProvider);
    final store = await ref.read(lockedStoreProvider.future);
    final files = await ref.read(fileStoreProvider.future);
    // ponytail: back to the folder it came from; a folder picker when users
    // want another place.
    final id = await store.moveOut(
      db,
      files,
      entry.id,
      cipher,
      folder: entry.fromFolder,
    );
    ref.invalidate(lockedFilesProvider);
    final row = await (db.select(
      db.files,
    )..where((f) => f.id.equals(id))).getSingle();
    final folder = row.folderId == null
        ? null
        : await (db.select(
            db.folders,
          )..where((f) => f.id.equals(row.folderId!))).getSingleOrNull();
    if (!context.mounted) return;
    showDkToast(context, l.toast_moved(folder?.name ?? l.shell_tab_files));
  }
}

/// A decrypted file on screen: its pages, nothing else (the viewer's tools
/// would write copies outside the vault).
class _LockedViewer extends StatelessWidget {
  const _LockedViewer({required this.name, required this.path});

  final String name, path;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.tokens.color.surfaceSunken,
    appBar: DkTopBar(title: name),
    body: DkPdfCanvas(path: path),
  );
}
