import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/core/firebase_options.dart';

void main() {
  test('reads production', () {
    expect(firebaseEnvFrom('production'), FirebaseEnv.production);
  });

  test('reads staging', () {
    expect(firebaseEnvFrom('staging'), FirebaseEnv.staging);
  });

  test('refuses any other value', () {
    for (final value in ['', 'prod', 'Staging', 'emulator']) {
      expect(() => firebaseEnvFrom(value), throwsStateError, reason: value);
    }
  });
}
