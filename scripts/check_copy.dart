import 'dart:convert';
import 'dart:io';

const _dir = 'lib/l10n';
const _allowPath = 'scripts/copy_allow.txt';
const _files = ['app_en.arb', 'app_ru.arb', 'app_kk.arb'];

const _bannedCharacters = {
  'em_dash': '—',
  'en_dash': '–',
  'middle_dot': '·',
  'bullet': '•',
  'hash': '#',
  'exclamation': '!',
};

const _bannedEnglishWords = [
  'unlock',
  'supercharge',
  'seamless',
  'elevate',
  'journey',
  'effortless',
  'magic',
  'powerful',
  'awesome',
  'oops',
  'whoops',
  'dive in',
];

void main(List<String> args) {
  final violations = _findViolations();

  if (args.contains('--write-baseline')) {
    File(_allowPath).writeAsStringSync(violations.map((v) => '$v\n').join());
    stdout.writeln('wrote ${violations.length} lines to $_allowPath');
    return;
  }

  final allowed =
      File(_allowPath).readAsLinesSync().where((l) => l.isNotEmpty).toSet();
  final added = violations.where((v) => !allowed.contains(v)).toList();
  final stale = allowed.difference(violations.toSet()).toList()..sort();

  for (final violation in added) {
    stdout.writeln('new copy violation: $violation');
  }
  for (final line in stale) {
    stdout.writeln('no longer violates, remove from $_allowPath: $line');
  }

  if (added.isNotEmpty || stale.isNotEmpty) exit(1);
  stdout.writeln('copy check passed: ${allowed.length} baselined violations');
}

List<String> _findViolations() {
  final violations = <String>[];
  for (final file in _files) {
    final arb = jsonDecode(File('$_dir/$file').readAsStringSync())
        as Map<String, dynamic>;
    for (final entry in arb.entries) {
      if (entry.key.startsWith('@')) continue;
      for (final rule in _brokenRules(file, entry.value as String)) {
        violations.add('$file:${entry.key}:$rule');
      }
    }
  }
  return violations..sort();
}

Iterable<String> _brokenRules(String file, String value) sync* {
  for (final rule in _bannedCharacters.entries) {
    if (value.contains(rule.value)) yield rule.key;
  }
  if (file != 'app_en.arb') return;
  for (final word in _bannedEnglishWords) {
    final pattern = RegExp('\\b$word\\b', caseSensitive: false);
    if (pattern.hasMatch(value)) yield 'word_${word.replaceAll(' ', '_')}';
  }
}
