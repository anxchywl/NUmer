import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/groups/groups.dart';

void main() {
  test('seven characters is too short', () {
    expect(isJoinCodeLongEnough('abc1234'), isFalse);
  });

  test('eight characters is enough', () {
    expect(isJoinCodeLongEnough('abc12345'), isTrue);
  });

  test('surrounding spaces do not count', () {
    expect(isJoinCodeLongEnough('  abc1234  '), isFalse);
  });
}
