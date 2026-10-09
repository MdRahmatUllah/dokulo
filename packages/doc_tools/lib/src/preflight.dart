import 'dart:io';
import 'dart:math' as math;

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';

import 'tool_job.dart';

/// The checks before a job starts (DK-0020), so no job starts that is known
/// to fail:
/// - storage: the inputs' size × the tool's [ToolJob.spaceFactor] must fit
///   in the free storage, or [DocErrorKind.notEnoughStorage] with the bytes
///   needed ("needs about 120 MB");
/// - memory: the largest input page rendered at the tool's
///   [ToolJob.renderDpi], times the pages it holds at once, must fit in
///   [memoryShare] of the free memory, or [DocErrorKind.tooLarge] ("Split it
///   first");
/// - encryption: an input that won't open without a password fails as
///   [DocErrorKind.locked] (T2 shows the inline password row).
///
/// A value the phone won't give never blocks (as DK-0013's rules).
class Preflight {
  const Preflight(this.readDevice, {this.memoryShare = 0.6});

  /// The phone's reading *now*: free storage and memory change while the app
  /// runs, so each check reads them again.
  final Future<DeviceCapabilities> Function() readDevice;

  /// The part of the free memory a job may use: the app, the decoders and
  /// the OS need the rest.
  final double memoryShare;

  Future<void> check<I>(ToolJob<I> tool, I input) async {
    final device = await readDevice();
    final files = tool.inputFiles(input);
    var inputBytes = 0;
    for (final file in files) {
      inputBytes += await File(file).length();
    }
    final needed = (inputBytes * tool.spaceFactor).ceil();
    if (storageShortfall(device, needed) > 0) {
      throw DocError(
        DocErrorKind.notEnoughStorage,
        bytes: needed,
        detail: 'needs $needed B, free ${device.freeStorage} B',
      );
    }

    final dpi = tool.renderDpi;
    final free = device.availableRam;
    final password = tool.passwordOf(input);
    for (final file in files.where((f) => f.toLowerCase().endsWith('.pdf'))) {
      // Opening it is also the encryption check: locked fails here.
      final info = await PdfEngine.inspect(file, password: password);
      if (dpi == 0 || free == null) continue;
      var largest = 0.0;
      for (final page in info.pages) {
        largest = math.max(largest, page.width * page.height);
      }
      final perPage = largest / (72 * 72) * dpi * dpi * 4; // RGBA
      final peak = perPage * math.min(tool.pagesInMemory, info.pageCount);
      if (peak > free * memoryShare) {
        throw DocError(
          DocErrorKind.tooLarge,
          detail: 'peak ${peak.round()} B, free $free B: $file',
        );
      }
    }
  }
}
