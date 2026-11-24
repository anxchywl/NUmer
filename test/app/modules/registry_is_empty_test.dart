import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/modules/module_registry.dart';

void main() {
  test('no module is registered yet', () {
    expect(moduleRegistry, isEmpty);
  });
}
