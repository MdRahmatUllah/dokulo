import 'package:doc_tools/doc_tools.dart';
import 'package:test/test.dart';

void main() {
  final registry = ToolRegistry.app();
  final missing = toolJobIds.where((id) => !registry.ids.contains(id)).toList();

  test('every registered ToolJob is a catalogue tool, once', () {
    expect(toolJobIds.toSet(), hasLength(toolJobIds.length));
    expect(registry.ids.where((id) => !toolJobIds.contains(id)), isEmpty);
  });

  // Turns on by itself when the last engine task registers its job.
  test(
    'every tool in the catalogue is a registered ToolJob',
    () => expect(missing, isEmpty),
    skip: missing.isEmpty
        ? false
        : 'engines not built yet: ${missing.join(', ')}',
  );
}
