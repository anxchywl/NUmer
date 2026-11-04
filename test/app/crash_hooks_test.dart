import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/bootstrap.dart';
import 'package:numer_app/core/observability/crash_reporter.dart';

class _RecordingReporter extends NoopCrashReporter {
  final records = <(Object, bool)>[];

  @override
  void recordError(Object error, StackTrace stack, {bool fatal = false}) {
    records.add((error, fatal));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('framework errors are recorded and still reach the old handler', () {
    final original = FlutterError.onError;
    final originalPlatform = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = original;
      PlatformDispatcher.instance.onError = originalPlatform;
    });
    final handled = <Object>[];
    FlutterError.onError = (details) => handled.add(details.exception);
    final reporter = _RecordingReporter();

    installCrashHooks(reporter);
    final error = StateError('framework');
    FlutterError.onError!(FlutterErrorDetails(exception: error));
    final asyncError = StateError('async');
    final caught = PlatformDispatcher.instance.onError!(
      asyncError,
      StackTrace.current,
    );

    expect(caught, isTrue);
    expect(handled, [error]);
    expect(reporter.records, [(error, true), (asyncError, true)]);
  });
}
