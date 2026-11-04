import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

abstract class CrashReporter {
  Future<void> init();

  void recordError(Object error, StackTrace stack, {bool fatal = false});

  void setUser(String? uid);
}

class FirebaseCrashReporter implements CrashReporter {
  @override
  Future<void> init() => FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(kReleaseMode);

  @override
  void recordError(Object error, StackTrace stack, {bool fatal = false}) {
    unawaited(
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal),
    );
  }

  @override
  void setUser(String? uid) {
    // crashlytics clears the identifier with an empty string
    unawaited(FirebaseCrashlytics.instance.setUserIdentifier(uid ?? ''));
  }
}

class NoopCrashReporter implements CrashReporter {
  @override
  Future<void> init() async {}

  @override
  void recordError(Object error, StackTrace stack, {bool fatal = false}) {}

  @override
  void setUser(String? uid) {}
}
