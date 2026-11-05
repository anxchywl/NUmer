import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/auth/auth.dart';

void main() {
  const reasons = {
    'malformed-code': CodeFailureReason.malformedCode,
    'invalid-code': CodeFailureReason.invalidCode,
    'code-expired': CodeFailureReason.codeExpired,
    'too-many-attempts': CodeFailureReason.tooManyAttempts,
    'rate-limited': CodeFailureReason.rateLimited,
    'no-active-code': CodeFailureReason.noActiveCode,
    'delivery-failed': CodeFailureReason.deliveryFailed,
    'no-email': CodeFailureReason.noEmail,
    'invalid-email': CodeFailureReason.invalidEmail,
    'malformed-input': CodeFailureReason.malformedInput,
    'invalid-or-expired-code': CodeFailureReason.invalidOrExpiredCode,
    'weak-password': CodeFailureReason.weakPassword,
    'invalid-or-expired-ticket': CodeFailureReason.invalidOrExpiredTicket,
  };

  for (final MapEntry(key: reason, value: expected) in reasons.entries) {
    test('maps $reason', () {
      final failure = codeFailureFor('internal', {'reason': reason});

      expect(failure.reason, expected);
    });
  }

  test('reads the attempts left and the retry delay', () {
    final invalid = codeFailureFor('permission-denied', {
      'reason': 'invalid-code',
      'attemptsLeft': 3,
    });
    final limited = codeFailureFor('resource-exhausted', {
      'reason': 'rate-limited',
      'retryAfterSeconds': 42,
    });

    expect(invalid.attemptsLeft, 3);
    expect(limited.retryAfterSeconds, 42);
  });

  test('maps an app check refusal and a new reason to unknown', () {
    for (final reason in ['app-check', 'something-new']) {
      final failure = codeFailureFor('failed-precondition', {'reason': reason});

      expect(failure.reason, CodeFailureReason.unknown);
    }
  });

  test('keeps the reason when the code also means offline', () {
    final expired = codeFailureFor('deadline-exceeded', {
      'reason': 'code-expired',
    });
    final undelivered = codeFailureFor('unavailable', {
      'reason': 'delivery-failed',
    });

    expect(expired.reason, CodeFailureReason.codeExpired);
    expect(undelivered.reason, CodeFailureReason.deliveryFailed);
  });

  test(
    'maps unavailable and deadline-exceeded without a reason to offline',
    () {
      for (final code in ['unavailable', 'deadline-exceeded']) {
        expect(codeFailureFor(code, null).reason, CodeFailureReason.offline);
      }
    },
  );

  test('maps any other error without a reason to unknown', () {
    expect(codeFailureFor('internal', null).reason, CodeFailureReason.unknown);
  });

  test('maps an unknown error without details to offline on ios only', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(codeFailureFor('unknown', null).reason, CodeFailureReason.offline);

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(codeFailureFor('unknown', null).reason, CodeFailureReason.unknown);
  });
}
