import 'dart:convert';
import 'dart:io';

/// Opt-in crash reports without any document content (DK-0011; the owner's
/// decision, 2026-10-07: no crash-reporting SDK, nothing leaves the phone on
/// its own). When the user turns it on (Settings → Privacy), crashes are kept
/// in a small local log; "Send report by email" puts the code, the device
/// facts and that log into an email the user sends, or doesn't.
///
/// What an entry keeps, and nothing else (the Privacy page lists exactly
/// this, docs/compliance/crash-reports.md): the time, our error code if any,
/// the error's type and the code locations of the stack trace. The error's
/// message is never kept: it can hold a file name or text from a document,
/// and no filter catches every file name.
class CrashEntry {
  const CrashEntry({
    required this.at,
    required this.type,
    required this.frames,
    this.code,
  });

  factory CrashEntry.of(Object error, StackTrace? stack, {String? code}) =>
      CrashEntry(
        at: DateTime.now().toUtc(),
        type: error.runtimeType.toString(),
        frames: codeFrames(stack),
        code: code,
      );

  factory CrashEntry.fromJson(Map<String, Object?> json) => CrashEntry(
    at: DateTime.parse(json['at']! as String),
    type: json['type']! as String,
    frames: [for (final f in json['frames']! as List<Object?>) f! as String],
    code: json['code'] as String?,
  );

  final DateTime at;
  final String type;
  final List<String> frames;

  /// Our error code, as the error message shows it ("DK-0142").
  final String? code;

  Map<String, Object?> toJson() => {
    'at': at.toIso8601String(),
    'type': type,
    'frames': frames,
    if (code != null) 'code': code,
  };
}

/// The stack trace's code locations: `package:` and `dart:` frames (and an
/// obfuscated build's addresses), at most [max]. Any file-system path, in a
/// debug build's `file://` frames for example, becomes `<path>`.
List<String> codeFrames(StackTrace? stack, {int max = 20}) {
  if (stack == null) return const [];
  final path = RegExp(
    r'(file:///|[A-Za-z]:\\|/(data|storage|var|private|Users|home)/)\S*',
  );
  return [
    for (final line in stack.toString().split('\n'))
      if (line.trim().isNotEmpty) line.trim().replaceAll(path, '<path>'),
  ].take(max).toList();
}

/// The local log: one JSON line per crash, the newest [keep] kept.
class CrashLog {
  CrashLog(this.file, {this.keep = 20});

  final File file;
  final int keep;

  Future<List<CrashEntry>> entries() async {
    if (!await file.exists()) return const [];
    final lines = await file.readAsLines();
    return [
      for (final line in lines)
        if (line.isNotEmpty)
          CrashEntry.fromJson(jsonDecode(line) as Map<String, Object?>),
    ];
  }

  Future<void> record(CrashEntry entry) async {
    final all = [...await entries(), entry];
    final kept = all.skip(all.length > keep ? all.length - keep : 0);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      kept.map((e) => '${jsonEncode(e.toJson())}\n').join(),
    );
  }

  Future<void> clear() async {
    if (await file.exists()) await file.delete();
  }
}

/// The email the user sends ("Send report by email"): subject with the code,
/// the device facts and the log. The recipient is left for the user's mail
/// app until the owner names a support address.
Uri reportEmail({
  required String? code,
  required Map<String, String> device,
  required List<CrashEntry> entries,
}) {
  final body = StringBuffer()
    ..writeln('Code: ${code ?? '-'}')
    ..writeln();
  device.forEach((k, v) => body.writeln('$k: $v'));
  for (final e in entries) {
    body
      ..writeln()
      ..writeln('${e.at.toIso8601String()} ${e.code ?? ''} ${e.type}')
      ..writeAll(e.frames.map((f) => '  $f\n'));
  }
  return Uri(
    scheme: 'mailto',
    query: _query({
      'subject': 'Dokulo report${code == null ? '' : ' $code'}',
      'body': body.toString(),
    }),
  );
}

// mailto wants %20, not the + that Uri.queryParameters writes.
String _query(Map<String, String> params) => params.entries
    .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
    .join('&');
