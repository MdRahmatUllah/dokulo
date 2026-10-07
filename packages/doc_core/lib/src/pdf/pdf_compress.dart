import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ai_core/ai_core.dart';
import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import 'package:pdfium_dart/pdfium_dart.dart' as fpdf;
import 'package:pdfrx_engine/pdfrx_engine.dart';
import 'package:qpdf_ffi/qpdf_ffi.dart';

import 'compress/raster_fallback.dart';
import 'compress/size_target.dart';
import 'pdf_engine.dart';
import 'qpdf_service.dart';

/// Compress PDF's three presets (T2 options).
enum CompressPreset {
  low((quality: 85, dpi: 200)),
  recommended((quality: 70, dpi: 150)),
  strong((quality: 50, dpi: 72));

  const CompressPreset(this.level);

  /// Its JPEG quality and image resolution.
  final CompressLevel level;
}

class CompressOptions {
  const CompressOptions({
    this.preset = CompressPreset.recommended,
    this.greyscale = false,
    this.removeMetadata = false,
    this.targetBytes,
  });

  final CompressPreset preset;

  /// Images in shades of grey (text and drawings keep their colour).
  final bool greyscale;

  /// Drops the document info (title, author, producer) and the XMP metadata.
  final bool removeMetadata;

  /// "Under X MB": the best quality that fits, at a resolution no sharper
  /// than [preset]'s ([searchSizeTarget]).
  final int? targetBytes;
}

class CompressResult {
  const CompressResult({
    required this.bytesBefore,
    required this.bytesAfter,
    required this.imagesRecompressed,
    required this.level,
    required this.targetMet,
  });

  final int bytesBefore;
  final int bytesAfter;

  /// Images re-encoded in place; pages rasterised by the fallback aren't
  /// counted.
  final int imagesRecompressed;

  /// The quality and resolution the output was made with.
  final CompressLevel level;

  /// False only when [CompressOptions.targetBytes] couldn't be reached: the
  /// output is then the smallest Dokulo can make.
  final bool targetMet;
}

/// Compress PDF's pipeline (DK-0392): every image above the target
/// resolution is resized and re-encoded as JPEG in its own image object, so
/// the page looks the same; scan pages whose images can't be re-encoded that
/// way are rendered whole ([RasterFallback], their OCR text kept); then qpdf
/// compresses the structure. A size target goes through [searchSizeTarget].
///
/// Call it from a `Lane.pdfium` job: PDFium runs on pdfrx's worker, the
/// image work and qpdf on the [pool]'s workers, never on the calling
/// isolate. Errors are [DocError]s.
class PdfCompress {
  PdfCompress(this.pool);

  final IsolatePool pool;

  Future<CompressResult> compress(
    String input,
    String output,
    CompressOptions options, {
    String? password,
    Directory? workDir,
    void Function(int pagesDone, int pages)? onPage,
    bool Function()? isCancelled,
  }) async {
    final before = await File(input).length();
    final work = await (workDir ?? Directory.systemTemp).createTemp(
      'dk_compress_',
    );
    try {
      Future<_Pass> pass(CompressLevel level) => _pass(
        input,
        '${work.path}/out_${level.dpi}_${level.quality}.pdf',
        options,
        level,
        password,
        work,
        onPage,
        isCancelled,
      );
      final target = options.targetBytes;
      if (target == null) {
        final made = await pass(options.preset.level);
        return await _finish(made, before, output, targetMet: true);
      }
      // ponytail: each try is a full pass; sample a few pages first if the
      // device timings (DK-1063) show it's slow.
      final passes = <CompressLevel, _Pass>{};
      final search = await searchSizeTarget(
        targetBytes: target,
        tryLevel: (level) async {
          final made = passes[level] = await pass(level);
          return (path: made.path, bytes: made.bytes);
        },
        dpis: [
          for (final dpi in const [200, 150, 100, 72])
            if (dpi <= options.preset.level.dpi) dpi,
        ],
      );
      return await _finish(
        passes[search.level]!,
        before,
        output,
        targetMet: search.fits,
      );
    } finally {
      await work.delete(recursive: true);
    }
  }

  Future<CompressResult> _finish(
    _Pass pass,
    int before,
    String output, {
    required bool targetMet,
  }) async {
    try {
      await File(pass.path).copy(output);
    } on FileSystemException catch (e) {
      final full =
          e.osError?.errorCode == 28 || e.osError?.errorCode == 112; // ENOSPC
      throw DocError(
        full ? DocErrorKind.notEnoughStorage : DocErrorKind.unexpected,
        detail: '$e',
      );
    }
    return CompressResult(
      bytesBefore: before,
      bytesAfter: pass.bytes,
      imagesRecompressed: pass.images,
      level: pass.level,
      targetMet: targetMet,
    );
  }

  /// One pass at [level]: images in place, the raster fallback, then qpdf's
  /// structure pass.
  Future<_Pass> _pass(
    String input,
    String output,
    CompressOptions options,
    CompressLevel level,
    String? password,
    Directory work,
    void Function(int, int)? onPage,
    bool Function()? isCancelled,
  ) async {
    final compute = PdfrxEntryFunctions.instance.compute;
    final (handle, pages) = await _call(
      () => compute(_openOnWorker, (input, password)),
    );
    var images = 0;
    final rasterise = <int>[];
    var imaged = '$output.images.pdf';
    try {
      for (var page = 0; page < pages; page++) {
        if (isCancelled?.call() ?? false) {
          throw const DocError(DocErrorKind.cancelled);
        }
        final (raws, scanLeftOver) = await _call(
          () => compute(_extractOnWorker, (handle, page, level.dpi)),
        );
        if (scanLeftOver) rasterise.add(page);
        if (raws.isNotEmpty) {
          final jpegs = await _job(
            pool.run(Lane.opencv, _encode, (
              raws,
              level.quality,
              options.greyscale,
            )).result,
          );
          final keep = [for (final j in jpegs) ?j];
          if (keep.isNotEmpty) {
            await _call(() => compute(_replaceOnWorker, (handle, page, keep)));
            images += keep.length;
          }
        }
        onPage?.call(page + 1, pages);
      }
      await File(imaged).writeAsBytes(
        await _call(() => compute(_saveOnWorker, handle)),
        flush: true,
      );
    } finally {
      await compute(_closeOnWorker, handle);
    }
    if (rasterise.isNotEmpty) {
      final rastered = '$output.raster.pdf';
      await RasterFallback.rasterise(
        imaged,
        rastered,
        rasterise,
        dpi: level.dpi,
        quality: level.quality,
        encodeJpeg: (rgba, width, height, quality) => _job(
          pool.run(Lane.opencv, _encodeRgba, (
            rgba,
            width,
            height,
            quality,
          )).result,
        ),
        work: work,
      );
      imaged = rastered;
    }
    await _job(
      pool.run(Lane.qpdf, _structure, (
        imaged,
        output,
        options.removeMetadata,
      )).result,
    );
    return _Pass(output, await File(output).length(), images, level);
  }

  static Future<T> _call<T>(Future<T> Function() pdfium) async {
    try {
      return await pdfium();
    } on DocError {
      rethrow;
    } catch (e) {
      throw DocError(DocErrorKind.unexpected, detail: 'PDFium: $e');
    }
  }

  /// A pool job's failure: a [DocError] thrown on the worker arrives as text.
  static Future<T> _job<T>(Future<T> result) async {
    try {
      return await result;
    } on JobFailed catch (e) {
      final kind = DocErrorKind.values.firstWhere(
        (k) => e.message.contains('DocError(${k.name}'),
        orElse: () => DocErrorKind.unexpected,
      );
      throw DocError(kind, detail: e.message);
    } on JobCancelled {
      throw const DocError(DocErrorKind.cancelled);
    }
  }
}

class _Pass {
  _Pass(this.path, this.bytes, this.images, this.level);

  final String path;
  final int bytes, images;
  final CompressLevel level;
}

/// An image object's pixels, as the encoder gets them.
class _Raw {
  _Raw(
    this.index,
    this.width,
    this.height,
    this.channels,
    this.pixels,
    this.targetWidth,
    this.targetHeight,
    this.encodedSize,
  );

  /// Its index among the page's objects.
  final int index;
  final int width, height;

  /// 1 grey, 3 BGR, 4 BGRx (the x is ignored).
  final int channels;
  final Uint8List pixels;
  final int targetWidth, targetHeight;

  /// The size of the image's stream in the file now.
  final int encodedSize;
}

// --- on a pool worker -------------------------------------------------------

/// Resizes and encodes each image; null where the JPEG isn't at least 10 %
/// smaller than what the file holds now.
List<(int, Uint8List)?> _encode(
  (List<_Raw>, int, bool) job,
  JobContext context,
) {
  final (raws, quality, makeGrey) = job;
  return [
    for (final raw in raws)
      () {
        // A grey image goes in as three equal channels: `image` reads a
        // one-channel pixel as red only.
        final grey = raw.channels == 1;
        final pixels = grey ? _expandGrey(raw.pixels) : raw.pixels;
        var image = img.Image.fromBytes(
          width: raw.width,
          height: raw.height,
          bytes: pixels.buffer,
          numChannels: grey ? 3 : raw.channels,
          order: grey || raw.channels == 3
              ? img.ChannelOrder.bgr
              : img.ChannelOrder.bgra,
        );
        if (raw.targetWidth < raw.width) {
          image = img.copyResize(
            image,
            width: raw.targetWidth,
            height: raw.targetHeight,
            interpolation: img.Interpolation.average,
          );
        }
        if (makeGrey && !grey) image = img.grayscale(image);
        final jpeg = img.encodeJpg(image, quality: quality);
        return jpeg.length < raw.encodedSize * 0.9 ? (raw.index, jpeg) : null;
      }(),
  ];
}

Uint8List _expandGrey(Uint8List grey) {
  final out = Uint8List(grey.length * 3);
  for (var i = 0; i < grey.length; i++) {
    out[3 * i] = out[3 * i + 1] = out[3 * i + 2] = grey[i];
  }
  return out;
}

/// The raster fallback's encoder: RGBA pixels as a JPEG.
Uint8List _encodeRgba((Uint8List, int, int, int) job, JobContext context) {
  final (rgba, width, height, quality) = job;
  return img.encodeJpg(
    img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    ),
    quality: quality,
  );
}

/// Compresses the structure; drops the metadata if asked.
void _structure((String, String, bool) job, JobContext context) {
  final (input, output, removeMetadata) = job;
  QpdfService.run(
    () => Qpdf.run({
      'inputFile': input,
      'outputFile': output,
      'objectStreams': 'generate',
      'compressStreams': 'y',
      'recompressFlate': '',
      'compressionLevel': '9',
      if (removeMetadata) ...{'removeInfo': '', 'removeMetadata': ''},
    }),
  );
}

// --- on pdfrx's PDFium worker ------------------------------------------------

/// Documents open across compute calls: handle → (document, its bytes).
final _open = <int, (fpdf.FPDF_DOCUMENT, Pointer<Uint8>)>{};
var _nextHandle = 0;

(int, int) _openOnWorker((String, String?) message) {
  final (path, password) = message;
  final pdfium = fpdf.getPdfium();
  // From memory: PDFium's path handling isn't UTF-8-safe everywhere (ß, ü, –).
  final bytes = File(path).readAsBytesSync();
  final buffer = malloc<Uint8>(bytes.length)
    ..asTypedList(bytes.length).setAll(0, bytes);
  final secret = password?.toNativeUtf8();
  final doc = pdfium.FPDF_LoadMemDocument64(
    buffer.cast(),
    bytes.length,
    (secret ?? nullptr).cast(),
  );
  if (secret != null) malloc.free(secret);
  if (doc == nullptr) {
    malloc.free(buffer);
    final code = pdfium.FPDF_GetLastError();
    throw DocError(
      code == 4 ? DocErrorKind.locked : DocErrorKind.damaged,
      detail: 'PDFium error $code: $path',
    );
  }
  _open[++_nextHandle] = (doc, buffer);
  return (_nextHandle, pdfium.FPDF_GetPageCount(doc));
}

void _closeOnWorker(int handle) {
  final open = _open.remove(handle);
  if (open == null) return;
  fpdf.getPdfium().FPDF_CloseDocument(open.$1);
  malloc.free(open.$2);
}

T _withPage<T>(
  int handle,
  int pageIndex,
  T Function(fpdf.PDFium, fpdf.FPDF_DOCUMENT, fpdf.FPDF_PAGE) body,
) {
  final pdfium = fpdf.getPdfium();
  final doc = _open[handle]!.$1;
  final page = pdfium.FPDF_LoadPage(doc, pageIndex);
  try {
    return body(pdfium, doc, page);
  } finally {
    pdfium.FPDF_ClosePage(page);
  }
}

/// The page's images worth recompressing, with their pixels at [dpi] at most,
/// and whether the page is a scan with an image left over that only the raster
/// fallback can shrink.
(List<_Raw>, bool) _extractOnWorker((int, int, int) message) {
  final (handle, pageIndex, dpi) = message;
  return _withPage(handle, pageIndex, (pdfium, doc, page) {
    final found = <_Raw>[];
    final count = pdfium.FPDFPage_CountObjects(page);
    // Visible text: an OCR layer (render mode 3, invisible) doesn't count.
    var hasText = false;
    for (var i = 0; i < count; i++) {
      final obj = pdfium.FPDFPage_GetObject(page, i);
      if (pdfium.FPDFPageObj_GetType(obj) == fpdf.FPDF_PAGEOBJ_TEXT &&
          pdfium.FPDFTextObj_GetTextRenderMode(obj) !=
              fpdf.FPDF_TEXT_RENDERMODE.FPDF_TEXTRENDERMODE_INVISIBLE) {
        hasText = true;
      }
    }
    var leftOver = false;
    final pageArea =
        pdfium.FPDF_GetPageWidthF(page) * pdfium.FPDF_GetPageHeightF(page);
    using((arena) {
      final meta = arena<fpdf.FPDF_IMAGEOBJ_METADATA>();
      final l = arena<Float>(),
          b = arena<Float>(),
          r = arena<Float>(),
          t = arena<Float>();
      for (var i = 0; i < count; i++) {
        final obj = pdfium.FPDFPage_GetObject(page, i);
        if (pdfium.FPDFPageObj_GetType(obj) != fpdf.FPDF_PAGEOBJ_IMAGE) {
          continue;
        }
        if (pdfium.FPDFImageObj_GetImageMetadata(obj, page, meta) == 0) {
          continue;
        }
        // 1-bit images (JBIG2, CCITT, masks) are already small; JPEG would grow them.
        if (meta.ref.bits_per_pixel <= 1 || meta.ref.width == 0) continue;
        final encodedSize = pdfium.FPDFImageObj_GetImageDataRaw(
          obj,
          nullptr,
          0,
        );
        pdfium.FPDFPageObj_GetBounds(obj, l, b, r, t);
        final widthPt = r.value - l.value;

        var bitmap = pdfium.FPDFImageObj_GetBitmap(obj);
        var format = bitmap == nullptr
            ? 0
            : pdfium.FPDFBitmap_GetFormat(bitmap);
        if (format == fpdf.FPDFBitmap_BGRA ||
            format == fpdf.FPDFBitmap_BGRA_Premul ||
            format == 0) {
          // Transparency or an undecodable image: kept here; on a scan page
          // (no visible text, the image covers it) the raster fallback
          // renders the whole page instead.
          if (bitmap != nullptr) pdfium.FPDFBitmap_Destroy(bitmap);
          final covers = widthPt * (t.value - b.value) >= 0.9 * pageArea;
          if (!hasText && covers) leftOver = true;
          continue;
        }
        try {
          final channels = switch (format) {
            fpdf.FPDFBitmap_Gray => 1,
            fpdf.FPDFBitmap_BGR => 3,
            _ => 4, // BGRx
          };
          final w = pdfium.FPDFBitmap_GetWidth(bitmap),
              h = pdfium.FPDFBitmap_GetHeight(bitmap);
          final stride = pdfium.FPDFBitmap_GetStride(bitmap);
          final src = pdfium.FPDFBitmap_GetBuffer(bitmap)
              .cast<Uint8>()
              .asTypedList(stride * h);
          final pixels = Uint8List(w * h * channels);
          for (var y = 0; y < h; y++) {
            pixels.setRange(
              y * w * channels,
              (y + 1) * w * channels,
              src,
              y * stride,
            );
          }
          // At most [dpi] where the image sits on the page (points are 1/72 in).
          final tw = (widthPt * dpi / 72).round().clamp(1, w);
          final th = (h * tw / w).round().clamp(1, h);
          found.add(_Raw(i, w, h, channels, pixels, tw, th, encodedSize));
        } finally {
          pdfium.FPDFBitmap_Destroy(bitmap);
        }
      }
    });
    return (found, leftOver);
  });
}

Uint8List _jpeg = Uint8List(0); // what the file-access callback reads

int _readJpeg(
  Pointer<Void> param,
  int position,
  Pointer<UnsignedChar> buffer,
  int size,
) {
  buffer.cast<Uint8>().asTypedList(size).setRange(0, size, _jpeg, position);
  return 1;
}

/// Puts each JPEG into its image object, in place, and rewrites the page's
/// content.
void _replaceOnWorker((int, int, List<(int, Uint8List)>) message) {
  final (handle, pageIndex, jpegs) = message;
  _withPage(handle, pageIndex, (pdfium, doc, page) {
    final read =
        NativeCallable<
          Int Function(
            Pointer<Void>,
            UnsignedLong,
            Pointer<UnsignedChar>,
            UnsignedLong,
          )
        >.isolateLocal(_readJpeg, exceptionalReturn: 0);
    final access = calloc<fpdf.FPDF_FILEACCESS>();
    final pages = calloc<fpdf.FPDF_PAGE>()..value = page;
    try {
      for (final (index, jpeg) in jpegs) {
        _jpeg = jpeg;
        access.ref
          ..m_FileLen = jpeg.length
          ..m_GetBlock = read.nativeFunction
          ..m_Param = nullptr;
        final obj = pdfium.FPDFPage_GetObject(page, index);
        if (pdfium.FPDFImageObj_LoadJpegFileInline(pages, 1, obj, access) ==
            0) {
          throw StateError(
            'FPDFImageObj_LoadJpegFileInline failed on object $index',
          );
        }
      }
      if (pdfium.FPDFPage_GenerateContent(page) == 0) {
        throw StateError('FPDFPage_GenerateContent failed');
      }
    } finally {
      _jpeg = Uint8List(0);
      calloc
        ..free(access)
        ..free(pages);
      read.close();
    }
  });
}

final _saved = BytesBuilder(copy: false);

int _writeBlock(
  Pointer<fpdf.FPDF_FILEWRITE> self,
  Pointer<Void> data,
  int size,
) {
  _saved.add(Uint8List.fromList(data.cast<Uint8>().asTypedList(size)));
  return 1;
}

/// The whole document, rewritten (never incremental).
Uint8List _saveOnWorker(int handle) {
  final pdfium = fpdf.getPdfium();
  final write =
      NativeCallable<
        Int Function(Pointer<fpdf.FPDF_FILEWRITE>, Pointer<Void>, UnsignedLong)
      >.isolateLocal(_writeBlock, exceptionalReturn: 0);
  final fw = calloc<fpdf.FPDF_FILEWRITE>()
    ..ref.version = 1
    ..ref.WriteBlock = write.nativeFunction;
  try {
    _saved.clear();
    if (pdfium.FPDF_SaveAsCopy(
          _open[handle]!.$1,
          fw,
          fpdf.FPDF_NO_INCREMENTAL,
        ) ==
        0) {
      throw StateError('FPDF_SaveAsCopy failed');
    }
    return _saved.takeBytes();
  } finally {
    calloc.free(fw);
    write.close();
  }
}
