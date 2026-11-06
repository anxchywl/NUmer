import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/core/firebase_options.dart';

void main() {
  test('reads production', () {
    expect(firebaseEnvFrom('production'), FirebaseEnv.production);
  });

  test('reads staging', () {
    expect(firebaseEnvFrom('staging'), FirebaseEnv.staging);
  });

  test('accepts a staging project id', () {
    expect(stagingProjectIdFrom('some-staging'), 'some-staging');
  });

  test('refuses the production project as staging', () {
    expect(() => stagingProjectIdFrom('numer-60744'), throwsStateError);
  });

  test('refuses any other value', () {
    for (final value in ['', 'prod', 'Staging', 'emulator']) {
      expect(() => firebaseEnvFrom(value), throwsStateError, reason: value);
    }
  });
}
