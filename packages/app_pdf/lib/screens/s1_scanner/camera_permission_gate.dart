import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/dk_button.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_illustration.dart';
import '../../components/dk_sheet.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/camera_permission.dart';
import '../../theme/dk_tokens.dart';

/// S1's camera permission (DK-0342; UI spec S1, design
/// `10-scanner/scanner-camera-prompt` and `-denied`):
///
/// - never asked: the camera's dark background with the pre-prompt sheet
///   (ILL-10, "Allow camera access"); Continue opens the system prompt, Not
///   now leaves the scanner ([onClose]);
/// - denied: full-screen black, ILL-10 inverted, "Open settings" and
///   "Import from photos" ([onImport]); the app never asks again, so the
///   system prompt can't loop. Coming back from Settings re-checks;
/// - granted: [camera].
class CameraPermissionGate extends ConsumerStatefulWidget {
  const CameraPermissionGate({
    super.key,
    required this.camera,
    required this.onClose,
    required this.onImport,
  });

  final WidgetBuilder camera;
  final VoidCallback onClose;
  final VoidCallback onImport;

  @override
  ConsumerState<CameraPermissionGate> createState() =>
      _CameraPermissionGateState();
}

class _CameraPermissionGateState extends ConsumerState<CameraPermissionGate> {
  CameraAccess? _access;
  late final AppLifecycleListener _lifecycle;

  CameraPermission get _permission => ref.read(cameraPermissionProvider);

  @override
  void initState() {
    super.initState();
    _check();
    // Back from Settings: the user may have turned the camera on.
    _lifecycle = AppLifecycleListener(onResume: _check);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final access = await _permission.status();
    if (mounted) setState(() => _access = access);
  }

  Future<void> _request() async {
    final access = await _permission.request();
    if (mounted) setState(() => _access = access);
  }

  @override
  Widget build(BuildContext context) => switch (_access) {
    null => ColoredBox(
      color: context.tokens.color.cameraChrome.withValues(alpha: 1),
    ),
    CameraAccess.granted => widget.camera(context),
    CameraAccess.notAsked => _PrePrompt(
      onContinue: _request,
      onNotNow: widget.onClose,
    ),
    CameraAccess.denied => _Denied(
      onSettings: _permission.openSettings,
      onImport: widget.onImport,
      onClose: widget.onClose,
    ),
  };
}

class _PrePrompt extends StatelessWidget {
  const _PrePrompt({required this.onContinue, required this.onNotNow});

  final VoidCallback onContinue, onNotNow;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    // The camera isn't open yet: its dark background under a 40 % scrim,
    // with the small sheet at the bottom.
    return ColoredBox(
      color: DkColors.dark.background,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: DkSheet(
          body: Padding(
            padding: EdgeInsets.fromLTRB(t.space.s, t.space.s, t.space.s, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DkIllustration(
                  DkIllustrations.cameraDenied,
                  scale: 80 / 120,
                ),
                SizedBox(height: t.space.l),
                Semantics(
                  header: true,
                  child: Text(
                    l.camera_access_title,
                    textAlign: TextAlign.center,
                    style: t.text.titleM.copyWith(color: t.color.textPrimary),
                  ),
                ),
                SizedBox(height: t.space.s),
                Text(
                  l.camera_access_body,
                  textAlign: TextAlign.center,
                  style: t.text.bodyM.copyWith(color: t.color.textSecondary),
                ),
                SizedBox(height: t.space.xl),
                DkButton(
                  label: l.common_continue,
                  onPressed: onContinue,
                  expand: true,
                  size: DkButtonSize.large,
                ),
                SizedBox(height: t.space.xs),
                DkButton(
                  label: l.common_not_now,
                  onPressed: onNotNow,
                  variant: DkButtonVariant.tertiary,
                  expand: true,
                  size: DkButtonSize.large,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Denied extends StatelessWidget {
  const _Denied({
    required this.onSettings,
    required this.onImport,
    required this.onClose,
  });

  final VoidCallback onSettings, onImport, onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final on = t.color.onCamera;
    return ColoredBox(
      // The camera's black (cameraChrome without its 60 %), both themes.
      color: t.color.cameraChrome.withValues(alpha: 1),
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: t.space.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Inverted on the black: the dark palette's colours.
                    const DkIllustration(
                      DkIllustrations.cameraDenied,
                      colors: DkColors.dark,
                    ),
                    SizedBox(height: t.space.xl),
                    Semantics(
                      header: true,
                      child: Text(
                        l.camera_off_title,
                        textAlign: TextAlign.center,
                        style: t.text.titleM.copyWith(color: on),
                      ),
                    ),
                    SizedBox(height: t.space.s),
                    Text(
                      l.camera_off_body,
                      textAlign: TextAlign.center,
                      style: t.text.bodyM.copyWith(
                        color: on.withValues(alpha: 0.75),
                      ),
                    ),
                    SizedBox(height: t.space.xl),
                    SizedBox(
                      width: 240,
                      child: Column(
                        spacing: t.space.m,
                        children: [
                          DkButton(
                            label: l.camera_open_settings,
                            onPressed: onSettings,
                            variant: DkButtonVariant.onCameraPrimary,
                            expand: true,
                          ),
                          DkButton(
                            label: l.scan_import_photos,
                            onPressed: onImport,
                            variant: DkButtonVariant.onCamera,
                            expand: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              child: IconButton(
                onPressed: onClose,
                tooltip: l.camera_close,
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                icon: DkIcon(DkIcons.close, color: on),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
