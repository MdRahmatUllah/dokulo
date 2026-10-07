/// Compress PDF's "under X MB" (DK-0392; Technology plan, `pdf_compress`): the
/// highest JPEG quality, at the highest resolution, whose output fits.
library;

/// One setting of the image pipeline: JPEG quality and image resolution.
typedef CompressLevel = ({int quality, int dpi});

/// One try: the file it wrote and its size.
typedef CompressTry = ({String path, int bytes});

/// What the search settled on.
class SizeTargetResult {
  const SizeTargetResult(
    this.level,
    this.output, {
    required this.fits,
    required this.tries,
  });

  final CompressLevel level;

  /// The file to keep: the best one that fits, or the smallest when none
  /// does ("Couldn't get under 2 MB; the smallest is 2.6 MB").
  final CompressTry output;
  final bool fits;

  /// How many times the pipeline ran, for the progress estimate and logs.
  final int tries;
}

/// Searches the resolutions from sharpest to smallest ([dpis]) and, within
/// one, the quality from [maxQuality] down to [minQuality] by bisection, for
/// the first setting whose output is at most [targetBytes]. [tryLevel] runs
/// the pipeline once (it writes a file) and is called at most about
/// `dpis.length × 7` times; a setting is never tried twice. Assumes size grows
/// with quality at a fixed resolution, which holds for JPEG re-encoding.
Future<SizeTargetResult> searchSizeTarget({
  required int targetBytes,
  required Future<CompressTry> Function(CompressLevel level) tryLevel,
  List<int> dpis = const [200, 150, 100, 72],
  int minQuality = 40,
  int maxQuality = 85,
}) async {
  final tried = <CompressLevel, CompressTry>{};
  Future<CompressTry> run(CompressLevel level) async =>
      tried[level] ??= await tryLevel(level);

  for (final dpi in dpis) {
    // The lowest quality first: if even that is too big, a smaller
    // resolution is needed and the bisection would be wasted.
    final lowest = await run((quality: minQuality, dpi: dpi));
    if (lowest.bytes > targetBytes) continue;
    var (good, bad) = (
      minQuality,
      maxQuality + 1,
    ); // good fits; bad doesn't (or is past the range)
    while (bad - good > 1) {
      final mid = (good + bad) ~/ 2;
      if ((await run((quality: mid, dpi: dpi))).bytes <= targetBytes) {
        good = mid;
      } else {
        bad = mid;
      }
    }
    final level = (quality: good, dpi: dpi);
    return SizeTargetResult(
      level,
      tried[level]!,
      fits: true,
      tries: tried.length,
    );
  }
  final smallest = tried.entries.reduce(
    (a, b) => a.value.bytes <= b.value.bytes ? a : b,
  );
  return SizeTargetResult(
    smallest.key,
    smallest.value,
    fits: false,
    tries: tried.length,
  );
}
