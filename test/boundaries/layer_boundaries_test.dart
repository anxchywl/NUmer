import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _allowlistPath = 'test/boundaries/allowlist.txt';
const _packagePrefix = 'package:numer_app/';
const _appState = 'lib/app/app_state.dart';

final _importPattern = RegExp(
  r'''^\s*import\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

void main() {
  final violations = _findViolations();
  final allowed = File(
    _allowlistPath,
  ).readAsLinesSync().where((line) => line.isNotEmpty).toSet();

  test('no new layer violations', () {
    final added = violations.difference(allowed).toList()..sort();
    expect(added, isEmpty, reason: 'new violations:\n${added.join('\n')}');
  });

  test('allowlist has no stale lines', () {
    final stale = allowed.difference(violations).toList()..sort();
    expect(
      stale,
      isEmpty,
      reason: 'remove from $_allowlistPath:\n${stale.join('\n')}',
    );
  });
}

Set<String> _findViolations() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .map((file) => file.path.replaceAll(r'\', '/'))
      .where((path) => path.endsWith('.dart'))
      .where((path) => !path.startsWith('lib/l10n/'));

  return {
    for (final importer in files)
      for (final match in _importPattern.allMatches(
        File(importer).readAsStringSync(),
      ))
        if (_resolve(importer, match.group(1)!) case final imported?)
          if (_isViolation(importer, imported)) '$importer -> $imported',
  };
}

String? _resolve(String importer, String uri) {
  if (uri.startsWith(_packagePrefix)) {
    return 'lib/${uri.substring(_packagePrefix.length)}';
  }
  if (Uri.parse(uri).hasScheme) return null;
  return Uri.parse(importer).resolve(uri).path;
}

bool _isViolation(String importer, String imported) {
  if (importer.startsWith('lib/shared/')) {
    return _isUnder(imported, ['lib/core/', 'lib/features/', 'lib/app/']);
  }
  if (importer.startsWith('lib/core/')) {
    return _isUnder(imported, ['lib/features/', 'lib/app/']);
  }
  final isRoot = importer.startsWith('lib/app/') || importer == 'lib/main.dart';
  if (isRoot) return _bypassesBarrel(imported);

  final feature = _featureOf(importer);
  if (feature == null) return false;
  if (imported.startsWith('lib/app/')) return imported != _appState;
  return _featureOf(imported) != feature && _bypassesBarrel(imported);
}

bool _isUnder(String path, List<String> roots) => roots.any(path.startsWith);

String? _featureOf(String path) {
  final parts = path.split('/');
  if (parts.length < 4 || parts[1] != 'features') return null;
  return parts[2];
}

bool _bypassesBarrel(String imported) {
  final feature = _featureOf(imported);
  if (feature == null) return false;
  return imported != 'lib/features/$feature/$feature.dart';
}
