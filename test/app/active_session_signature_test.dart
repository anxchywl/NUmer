import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart' show activeSessionSignature;

void main() {
  String signature({
    bool isStudying = true,
    String? courseId = 'course',
    String? kind = 'timer',
    int? startMs = 1,
    int? expectedEndMs = 2,
  }) =>
      activeSessionSignature(
        isStudying: isStudying,
        courseId: courseId,
        kind: kind,
        startMs: startMs,
        expectedEndMs: expectedEndMs,
      );

  test('equal values give equal signatures', () {
    expect(signature(), signature());
  });

  test('any one differing value changes the signature', () {
    final variants = [
      signature(),
      signature(isStudying: false),
      signature(courseId: 'other'),
      signature(courseId: null),
      signature(kind: 'stopwatch'),
      signature(kind: null),
      signature(startMs: 3),
      signature(startMs: null),
      signature(expectedEndMs: 3),
      signature(expectedEndMs: null),
    ];

    expect(variants.toSet(), hasLength(variants.length));
  });
}
