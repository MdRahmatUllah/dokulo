import 'package:doc_core/doc_core.dart';
import 'package:doc_tools/doc_tools.dart';
import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

/// The values of a tool's options, by [ToolOption.key].
typedef ToolValues = Map<String, Object?>;

/// What a tool runs on, as T2 shows it: the input files, in order.
class ToolSubject {
  const ToolSubject(this.files, {this.passwords = const {}});

  final List<FileEntry> files;

  /// The passwords the user gave for locked inputs, by path (T2, DK-0372).
  final Map<String, String> passwords;

  /// The password of [file], if it needed one.
  String? passwordOf(FileEntry file) => passwords[file.path];

  /// All pages of all files ("Compress 12 pages").
  int get pages => files.fold(0, (n, f) => n + f.pages);
}

/// A finished run, as T3 shows it (DK-0379): the inputs, what the job wrote
/// (in temp, until saved), and how long it took.
class ToolResult {
  const ToolResult({
    required this.toolId,
    required this.inputs,
    required this.output,
    required this.took,
    this.chain = const [],
  });

  final String toolId;
  final List<FileEntry> inputs;
  final JobOutput output;
  final Duration took;

  /// The tools run so far in this chain, this one last (DK-0386): after two,
  /// T3 offers "Save as workflow".
  final List<String> chain;

  /// The files the job wrote.
  List<String> get files => switch (output) {
    OneFile(:final path) => [path],
    ManyFiles(:final paths) => paths,
    TextOutput() => const [],
  };
}

/// T3's result card for a run (UI spec §20.4): the headline (always a
/// number, or a count in a sentence: "Text found on 11 of 12 pages"), its
/// delta ("(−77 %)"), the line under it, and for a partial result the
/// warning tint with one inline action ("Retake page 7").
class ToolSummary {
  const ToolSummary({
    required this.headline,
    required this.sub,
    this.delta,
    this.partial = false,
    this.action,
    this.onAction,
  }) : assert((action == null) == (onAction == null), 'an action needs both');

  final String headline, sub;
  final String? delta;
  final bool partial;
  final String? action;
  final void Function(BuildContext context)? onAction;
}

/// Where a tool's job writes, and the words it needs (the engine has none).
class ToolEnv {
  const ToolEnv({required this.outputDir, required this.l10n});

  /// A temp folder of the file store; T3 saves from there.
  final String outputDir;
  final AppLocalizations l10n;
}

/// One option of a tool, rendered by T2 (UI spec §20.1 region 4) as a
/// DkOptionRow. A tool declares its options; the shell draws them, keeps the
/// chosen values while the user goes back and forth, and resets them.
sealed class ToolOption {
  const ToolOption({required this.key, required this.title, this.help});

  /// Its value's key in [ToolValues]; unique within a tool.
  final String key;
  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations)? help;

  Object? get initial;
}

/// On or off: a DkSwitch to the right.
final class ToolSwitch extends ToolOption {
  const ToolSwitch({
    required super.key,
    required super.title,
    super.help,
    this.initial = false,
  });

  @override
  final bool initial;
}

/// One of 2–4: a DkSegmented under the text.
final class ToolSegments<T extends Object> extends ToolOption {
  const ToolSegments({
    required super.key,
    required super.title,
    super.help,
    required this.values,
    required this.label,
    required this.initial,
  });

  final List<T> values;
  final String Function(AppLocalizations, T) label;

  @override
  final T initial;

  /// The segments with their labels, typed here where [T] is known.
  List<(Object, String)> segments(AppLocalizations l) => [
    for (final v in values) (v, label(l, v)),
  ];
}

/// Anything else (level cards, chips, a range or text field): the tool
/// builds the control, under the text.
final class ToolCustom extends ToolOption {
  const ToolCustom({
    required super.key,
    required super.title,
    super.help,
    required this.initial,
    required this.builder,
  });

  @override
  final Object? initial;

  final Widget Function(
    BuildContext context,
    ToolSubject subject,
    Object? value,
    ValueChanged<Object?> onChanged,
  )
  builder;
}

/// A tool as T2 renders and runs it (DK-0370): its options, the "More
/// options" ones, the main button's label, the estimate, and how its job's
/// input is made. Each tool's own task fills in its definition; until then a
/// tool shows its input and its name on a disabled button.
class ToolDefinition {
  const ToolDefinition({
    required this.id,
    this.options = const [],
    this.moreOptions = const [],
    this.action,
    this.estimate,
    this.input,
    this.busyLabel,
    this.busyTitle,
    this.doneTitle,
    this.stopTitle,
    this.summary,
    this.partLine,
    this.next = const [],
    this.preview,
  });

  final String id;
  final List<ToolOption> options;

  /// Behind the collapsible "More options" row.
  final List<ToolOption> moreOptions;

  /// The main button: verb, object, number ("Compress 12 pages", UI spec
  /// §21); null: the tool's name.
  final String Function(AppLocalizations, ToolSubject)? action;

  /// The caption above the button ("About 1.8 MB · 12 pages"); null: none.
  final String? Function(AppLocalizations, ToolSubject, ToolValues)? estimate;

  /// The job's input from the files and options; null: the tool can't run
  /// yet.
  final Object Function(ToolSubject, ToolValues, ToolEnv)? input;

  /// The button while it runs ("Compressing…", UI spec §20.2); null: "Working…".
  final String Function(AppLocalizations)? busyLabel;

  /// The progress sheet's title ("Compressing Mietvertrag.pdf"); null: the
  /// tool's name.
  final String Function(AppLocalizations, ToolSubject)? busyTitle;

  /// Home's continue card for a run that finished in the background
  /// ("Compressed Mietvertrag.pdf" / "Mietvertrag.pdf verkleinert", UI spec
  /// §15.2, DK-0247); null: "Compress PDF · Mietvertrag.pdf".
  final String Function(AppLocalizations, String file)? doneTitle;

  /// The cancel dialog's title ("Stop compressing?"); null: "Stop this job?".
  final String Function(AppLocalizations)? stopTitle;

  /// T3's card (DK-0383: a partial result); null: the output's size, or "3
  /// files", with "From Zeugnisse.pdf · 34 pages".
  final ToolSummary Function(AppLocalizations, ToolResult)? summary;

  /// A part's line in a multi-file result ("Pages 1–3 · 420 KB", DK-0384);
  /// null: its size.
  final String Function(AppLocalizations, ToolResult, int part)? partLine;

  /// T3's Next chips, 2–4 tool ids (UI spec §21 "Next"): each opens that
  /// tool with this result as its input (DK-0386).
  final List<String> next;

  /// A large tablet's live preview pane (DK-0388): the input with the
  /// options applied (Compress's before/after, a watermark, page numbers);
  /// null: the first PDF input as it is.
  final Widget Function(BuildContext, ToolSubject, ToolValues)? preview;

  /// Every option's starting value.
  ToolValues get initialValues => {
    for (final o in [...options, ...moreOptions]) o.key: o.initial,
  };
}

/// Every tool's definition. A tool's task adds its own here.
abstract final class ToolDefinitions {
  static final Map<String, ToolDefinition> _defined = {
    for (final d in <ToolDefinition>[]) d.id: d,
  };

  /// The definition of [toolId]; a plain one for a tool without its own.
  static ToolDefinition of(String toolId) =>
      _defined[toolId] ?? ToolDefinition(id: toolId);
}
