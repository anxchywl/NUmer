import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// modules take this package whole, so a dependency here lands in every one
void main() {
  test('the package depends on flutter only', () {
    final entries = File('pubspec.yaml')
        .readAsLinesSync()
        .skipWhile((line) => line != 'dependencies:')
        .skip(1)
        .takeWhile((line) => line.isEmpty || line.startsWith(' '))
        .where((line) => RegExp(r'^  \S').hasMatch(line))
        .map((line) => line.trim());

    expect(entries, ['flutter:']);
  });
}
