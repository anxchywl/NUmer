import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/core/observability/crash_reporter.dart';

void main() {
  test('noop reporter accepts every call', () async {
    final CrashReporter reporter = NoopCrashReporter();

    await expectLater(reporter.init(), completes);
    expect(
      () => reporter.recordError(StateError('boom'), StackTrace.current),
      returnsNormally,
    );
    expect(
      () => reporter.recordError(
        StateError('boom'),
        StackTrace.current,
        fatal: true,
      ),
      returnsNormally,
    );
    expect(() => reporter.setUser('uid'), returnsNormally);
    expect(() => reporter.setUser(null), returnsNormally);
  });
}
