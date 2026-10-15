import 'dart:io';

import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/database_providers.dart';
import '../../providers/file_providers.dart';
import '../s1_scanner/scan_session.dart';
import '../s1_scanner/scanner_settings.dart';
import '../t2_tool/tool_run.dart';
import 'save_sheet.dart';
import 'scan_result_screen.dart';

/// Saves the scan's pages as the Save sheet chose and returns what the
/// result screen shows; [onPage] counts the pages rendered.
typedef ScanSaver =
    Future<SavedScan> Function(
      List<ScannedPage> pages,
      ScanSaveOptions options, {
      void Function(int done)? onPage,
    });

/// The real save (DK-0359): every page warped, turned, filtered and scaled
/// on a worker isolate ([saveScan]); "Make text searchable" runs the OCR
/// tool over the PDF; the file goes into Files (the chosen folder) and the
/// index.
final scanSaverProvider = Provider<ScanSaver>(
  (ref) =>
      (pages, options, {onPage}) async {
        final store = await ref.read(fileStoreProvider.future);
        final settings = ref.read(scannerSettingsProvider);
        final work = await store.workDirectory.createTemp('scan_');
        try {
          final name = options.name.replaceAll(
            RegExp(r'\.(pdf|jpe?g)$', caseSensitive: false),
            '',
          );
          final jpg = options.format == ScanFormat.jpg;
          var outputs = await saveScan(
            [
              for (final p in pages)
                (
                  photo: p.path,
                  corners: [for (final c in p.corners) (x: c.dx, y: c.dy)],
                  turns: p.turns,
                  filter: ScanFilter.values.byName(
                    (p.filter ?? settings.filter).name,
                  ),
                  brightness: p.brightness,
                  contrast: p.contrast,
                ),
            ],
            base: '${work.path}/$name',
            workDir: work,
            jpg: jpg,
            size: switch (options.pageSize) {
              ScanPageSize.auto => ImagePageSize.fit,
              ScanPageSize.a4 => ImagePageSize.a4,
              ScanPageSize.letter => ImagePageSize.letter,
            },
            longSide: options.quality.longSide,
            jpegQuality: options.quality.jpeg,
            onPage: onPage,
          );
          int? textPages;
          Future<void> Function()? discardOcr;
          if (options.searchable && !jpg) {
            final run = await ref.read(toolRunnerProvider)(
              'ocr',
              (dir) => OcrInput.fromJson({
                'files': outputs,
                'outputDir': dir,
                'suffix': '',
                'language': settings.ocrLanguage.name,
              }),
            );
            discardOcr = run.discard;
            if (await run.result case OneFile(:final path)) outputs = [path];
            textPages = (await PdfEngine.pageTexts(
              outputs.single,
            )).where((t) => t.trim().isNotEmpty).length;
          }
          final db = ref.read(appDatabaseProvider);
          FileEntry? first;
          var bytes = 0;
          for (final out in outputs) {
            final file = File(out);
            bytes += await file.length();
            final saved = await store.saveIndexed(
              db,
              file,
              name: file.uri.pathSegments.last,
              subfolder: options.folder,
            );
            first ??= saved;
          }
          await discardOcr?.call();
          return (
            name: first!.name,
            fileId: first.id,
            path: first.path,
            pages: pages.length,
            bytes: bytes,
            textPages: textPages,
            folder: options.folder,
          );
        } finally {
          if (await work.exists()) await work.delete(recursive: true);
        }
      },
);
