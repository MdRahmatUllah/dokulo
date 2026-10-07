/// What the phone can do (DK-0013): memory, CPU architecture, storage and OS,
/// as Sogda checks them, and the rules built on them: whether an AI model is
/// offered at all, whether it may load right now, and how much space a
/// download or a job is short of.
library;

import 'dart:math' as math;

/// One reading of the phone. A value the platform won't give is null; a rule
/// never blocks on a null (as in Sogda: a guess must not block the user).
class DeviceCapabilities {
  const DeviceCapabilities({
    this.totalRam,
    this.availableRam,
    this.freeStorage,
    this.totalStorage,
    this.abis = const [],
    this.os = '',
    this.osVersion = '',
  });

  /// From the platform channel's map (`dokulo/device` → `capabilities`).
  factory DeviceCapabilities.fromMap(Map<Object?, Object?> map) {
    int? bytes(String key) => switch (map[key]) {
      final int v when v > 0 => v,
      _ => null,
    };
    return DeviceCapabilities(
      totalRam: bytes('totalRam'),
      availableRam: bytes('availableRam'),
      freeStorage: bytes('freeStorage'),
      totalStorage: bytes('totalStorage'),
      abis: [for (final a in (map['abis'] as List<Object?>? ?? const [])) '$a'],
      os: '${map['os'] ?? ''}',
      osVersion: '${map['osVersion'] ?? ''}',
    );
  }

  /// Bytes of memory in all, and free right now.
  final int? totalRam, availableRam;

  /// Bytes of storage free and in all, on the volume the app's files live on.
  final int? freeStorage, totalStorage;

  /// The CPU ABIs the phone runs, preferred first (`arm64-v8a`,
  /// `armeabi-v7a`, …). iOS reports `arm64`.
  final List<String> abis;

  /// `android` or `ios`, and the OS version (`14`, `17.6`).
  final String os, osVersion;

  /// AI needs a 64-bit ARM CPU. An armeabi-v7a phone gets every tool, no AI.
  /// An empty list (the phone won't say) counts as arm64.
  bool get isArm64 => abis.isEmpty || abis.any((a) => a.startsWith('arm64'));
}

/// What an on-device model asks of the phone.
class ModelNeeds {
  const ModelNeeds({
    required this.ramFloor,
    required this.advertisedGb,
    required this.workingSet,
  });

  /// The least memory in all the model is offered on, in bytes. A phone sold
  /// as "6 GB" reports less (the kernel and the modem keep the rest), so the
  /// floor sits below the advertised size, as Sogda's Hy-MT2 floor does.
  final int ramFloor;

  /// The size the not-eligible sheet names: "It needs at least 6 GB".
  final int advertisedGb;

  /// Bytes the loaded model uses; loading needs this plus [loadHeadroom] free.
  final int workingSet;
}

const _mib = 1024 * 1024;

/// Free memory a load must leave over the working set (Technology plan:
/// "available RAM ≥ working set + 300 MB").
const loadHeadroom = 300 * _mib;

/// Gemma 4 E2B, Q4_K_M: a "6 GB" phone (A1 not eligible: "It needs at least
/// 6 GB"), 2–3 GB working set (the top of the range).
const gemmaNeeds = ModelNeeds(
  ramFloor: 5632 * _mib, // 5.5 GiB: what a "6 GB" phone reports
  advertisedGb: 6,
  workingSet: 3072 * _mib,
);

/// Why a model is or isn't available.
enum AiEligibility {
  eligible,

  /// A 32-bit phone: no AI entries at all.
  notArm64,

  /// Too little memory in all: the A1 "not eligible" sheet.
  tooLittleRam,
}

/// Whether [needs] is offered on this phone at all.
AiEligibility eligibility(DeviceCapabilities device, ModelNeeds needs) {
  if (!device.isArm64) return AiEligibility.notArm64;
  final total = device.totalRam;
  if (total != null && total < needs.ramFloor) {
    return AiEligibility.tooLittleRam;
  }
  return AiEligibility.eligible;
}

/// Whether [needs] may load now: enough free memory for its working set plus
/// the headroom. False means "close some apps and try again", not "never".
bool canLoadNow(DeviceCapabilities device, ModelNeeds needs) {
  final free = device.availableRam;
  return free == null || free >= needs.workingSet + loadHeadroom;
}

/// The bytes a download or a job of [needed] bytes is short of on this
/// phone, 0 when it fits or when the phone won't say ("needs about 120 MB").
int storageShortfall(DeviceCapabilities device, int needed) =>
    device.freeStorage == null ? 0 : math.max(0, needed - device.freeStorage!);

/// The phone's memory as the sheet names it, rounded up to whole GB: a phone
/// reporting 3.6 GiB "has 4 GB".
int advertisedGb(int totalRam) => (totalRam / (1024 * _mib)).ceil();
