import 'dart:io';

const _baselinePath = 'scripts/design_baseline.txt';
const _roots = ['lib', 'packages'];
const _tokensPath = 'packages/numer_ui/lib/src/tokens/';
const _buttonChildPath =
    'packages/numer_ui/lib/src/components/numer_button_child.dart';
const _messagePath =
    'packages/numer_ui/lib/src/components/numer_message.dart';

const _exempt = {
  'color_literal': [_tokensPath],
  'text_literal': [_tokensPath],
  'spinner': [_buttonChildPath],
  'snackbar': [_messagePath],
  'shadow': [_messagePath],
};

final _patterns = {
  'gradient': RegExp(r'\b(Linear|Radial|Sweep)Gradient\b'),
  'blur': RegExp(r'\bBackdropFilter\b|ImageFilter\.blur'),
  'shadow': RegExp(r'\bBoxShadow\(|elevation:\s*[1-9]'),
  'chip': RegExp(r'\b(Choice|Filter|Input|Action)?Chip\(|\bBadge\('),
  'color_literal': RegExp(r'\bColors\.(?!transparent\b)\w+|\bColor\(0x'),
  'text_literal':
      RegExp(r'\bTextStyle\(|\bfontSize:|\bfontFamily:|\bGoogleFonts\b'),
  'weight': RegExp(r'FontWeight\.w(600|800|900)'),
  'spinner': RegExp(r'\bCircularProgressIndicator\b'),
  'snackbar': RegExp(r'\bSnackBar\('),
  'alert': RegExp(r'\bAlertDialog\('),
  'button': RegExp(r'\b(Outlined|Elevated)Button\b'),
  'icon_pack': RegExp(
      r'\b(MdiIcons|PhosphorIcons|FontAwesomeIcons|LucideIcons|SimpleIcons)\b'),
  'opacity': RegExp(r'\.withOpacity\(|\bOpacity\('),
  'print': RegExp(r'\bdebugPrint\(|\bprint\('),
};

void main(List<String> args) {
  final counts = _countMatches();

  if (args.contains('--write-baseline')) {
    final lines = counts.entries.map((e) => '${e.key}\t${e.value}\n');
    File(_baselinePath).writeAsStringSync(lines.join());
    stdout.writeln('wrote ${counts.length} lines to $_baselinePath');
    return;
  }

  final baseline = _readBaseline();
  var failures = 0;
  for (final entry in counts.entries) {
    final allowed = baseline[entry.key] ?? 0;
    if (entry.value <= allowed) continue;
    final [id, path] = entry.key.split('\t');
    stdout.writeln('$path: $id count ${entry.value}, baseline $allowed');
    failures++;
  }

  if (failures > 0) exit(1);
  stdout.writeln('design check passed');
}

Map<String, int> _countMatches() {
  final counts = <String, int>{};
  for (final path in _dartFiles()) {
    final source = File(path).readAsStringSync();
    for (final pattern in _patterns.entries) {
      if (_isExempt(pattern.key, path)) continue;
      final count = pattern.value.allMatches(source).length;
      if (count > 0) counts['${pattern.key}\t$path'] = count;
    }
  }
  return counts;
}

bool _isExempt(String id, String path) {
  final prefixes = _exempt[id];
  return prefixes != null && prefixes.any(path.startsWith);
}

List<String> _dartFiles() {
  final paths = _roots
      .map(Directory.new)
      .where((root) => root.existsSync())
      .expand((root) => root.listSync(recursive: true))
      .whereType<File>()
      .map((file) => file.path.replaceAll(r'\', '/'))
      .where((path) => path.endsWith('.dart'))
      .where((path) => !path.startsWith('lib/l10n/'))
      .where((path) => !path.contains('/.dart_tool/'))
      .toList();
  return paths..sort();
}

Map<String, int> _readBaseline() {
  final baseline = <String, int>{};
  for (final line in File(_baselinePath).readAsLinesSync()) {
    if (line.isEmpty) continue;
    final [id, path, count] = line.split('\t');
    baseline['$id\t$path'] = int.parse(count);
  }
  return baseline;
}
