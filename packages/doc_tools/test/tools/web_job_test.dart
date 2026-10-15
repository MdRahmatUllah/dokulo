import 'dart:io';

import 'package:ai_core/ai_core.dart';
import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:test/test.dart';
import 'package:web_to_pdf/web_to_pdf.dart';

/// The platform's printing, without a web view: writes a stand-in PDF, or
/// fails as offline.
class _Printer extends WebToPdf {
  _Printer({this.offline = false});

  final bool offline;
  final calls = <Object>[];

  Future<int> _write(Object source, String outputPath) async {
    calls.add(source);
    File(outputPath).writeAsStringSync('%PDF-1.7 stand-in');
    if (offline) throw const WebToPdfException(WebToPdfError.loadFailed);
    return 3;
  }

  @override
  Future<int> fromUrl(
    Uri url,
    String outputPath, {
    PageSize pageSize = PageSize.a4,
    bool backgrounds = true,
    bool margins = true,
    Duration timeout = const Duration(seconds: 30),
  }) => _write(url, outputPath);

  @override
  Future<int> fromHtml(
    String html,
    String outputPath, {
    Uri? baseUrl,
    PageSize pageSize = PageSize.a4,
    bool backgrounds = true,
    bool margins = true,
    Duration timeout = const Duration(seconds: 30),
  }) => _write(html, outputPath);
}

void main() {
  late Directory dir, outDir;
  late DokuloDatabase db;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dk_web_job_');
    outDir = Directory('${dir.path}/out')..createSync();
    db = DokuloDatabase.memory();
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  JobQueue queueWith(WebToPdf printer) => JobQueue(
    IsolatePool(tempRoot: Directory('${dir.path}/jobs')..createSync()),
    db,
    ToolRegistry([WebJob(printer: printer)]),
  );

  test('web is registered; its input survives JSON', () {
    final job = ToolRegistry.app()['web'];
    final json = job.encode(
      WebInput(outputDir: outDir.path, address: 'example.com', margins: false),
    );
    expect(job.encode(job.decode(json)), json);
  });

  test('an address: https added, the PDF named after the site', () async {
    final printer = _Printer();
    final run = await queueWith(printer).start(
      'web',
      WebInput(outputDir: outDir.path, address: 'www.example.com/artikel'),
    );
    final out = await run.result as OneFile;
    expect(printer.calls.single, Uri.parse('https://www.example.com/artikel'));
    expect(out.path, '${outDir.path}/example.com.pdf');
  });

  test(
    'an HTML file: printed with its folder as the base, named after it',
    () async {
      final page = File('${dir.path}/Rezept.html')
        ..writeAsStringSync('<h1>Rezept</h1>');
      final printer = _Printer();
      final run = await queueWith(printer)
          .start('web', WebInput(outputDir: outDir.path, htmlFile: page.path));
      final out = await run.result as OneFile;
      expect(printer.calls.single, '<h1>Rezept</h1>');
      expect(out.path, '${outDir.path}/Rezept.pdf');
    },
  );

  test('offline: fails as loadFailed and leaves nothing', () async {
    final run = await queueWith(_Printer(offline: true))
        .start('web', WebInput(outputDir: outDir.path, address: 'example.com'));
    await expectLater(
      run.result,
      throwsA(
        isA<JobFailed>().having(
          (e) => e.message,
          'message',
          contains('loadFailed'),
        ),
      ),
    );
    expect(outDir.listSync(), isEmpty);
  });
}
