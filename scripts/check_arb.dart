import 'dart:convert';
import 'dart:io';

const _files = ['app_en.arb', 'app_ru.arb', 'app_kk.arb'];

void main(List<String> args) {
  final dir = args.isEmpty ? 'lib/l10n' : args.first;
  final keys = {for (final file in _files) file: _readKeys('$dir/$file')};
  final allKeys = keys.values.expand((k) => k).toSet().toList()..sort();

  var missing = 0;
  for (final key in allKeys) {
    for (final file in _files) {
      if (keys[file]!.contains(key)) continue;
      stdout.writeln('$dir/$file: missing key $key');
      missing++;
    }
  }

  if (missing > 0) exit(1);
  stdout.writeln('arb keys match: ${allKeys.length} in each file');
}

Set<String> _readKeys(String path) {
  final arb = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return arb.keys.where((key) => !key.startsWith('@')).toSet();
}
