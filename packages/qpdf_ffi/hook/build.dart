// Builds qpdf from pinned source (src/CMakeLists.txt) and ships it as this
// package's code asset (DK-0391). The native-assets cache is keyed on this
// file's content: after changing src/CMakeLists.txt, touch this comment too.
// src/CMakeLists.txt rev 3.

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_cmake/native_toolchain_cmake.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final logger = Logger('')
      ..level = Level.INFO
      // ignore: avoid_print
      ..onRecord.listen((record) => print(record.message));
    final install = input.outputDirectory.resolve('install/');
    await CMakeBuilder.create(
      name: input.packageName,
      sourceDir: input.packageRoot.resolve('src/'),
      targets: ['install'],
      defines: {'CMAKE_INSTALL_PREFIX': install.toFilePath()},
      logger: logger,
    ).run(input: input, output: output, logger: logger);
    await output.findAndAddCodeAssets(
      input,
      outDir: install,
      names: {r'(lib)?qpdf\d*\.(so|dll|dylib)': 'src/bindings.dart'},
      regExp: true,
      logger: logger,
    );
  });
}
