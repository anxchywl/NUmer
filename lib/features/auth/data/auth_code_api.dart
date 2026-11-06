import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

sealed class CodeResult {
  const CodeResult();
}

class CodeOk extends CodeResult {
  const CodeOk(this.data);

  final Map<String, dynamic> data;
}

class CodeFailure extends CodeResult {
  const CodeFailure(this.reason, {this.attemptsLeft, this.retryAfterSeconds});

  final CodeFailureReason reason;
  final int? attemptsLeft;
  final int? retryAfterSeconds;
}

enum CodeFailureReason {
  malformedCode,
  invalidCode,
  codeExpired,
  tooManyAttempts,
  rateLimited,
  noActiveCode,
  deliveryFailed,
  noEmail,
  invalidEmail,
  malformedInput,
  invalidOrExpiredCode,
  weakPassword,
  invalidOrExpiredTicket,
  offline,
  unknown,
}

const _reasons = {
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

CodeFailure codeFailureFor(String code, Object? details) {
  final data = details is Map ? details : const {};
  final reason = data['reason'];
  if (reason == null) {
    return CodeFailure(
      _isOffline(code, details)
          ? CodeFailureReason.offline
          : CodeFailureReason.unknown,
    );
  }
  return CodeFailure(
    _reasons[reason] ?? CodeFailureReason.unknown,
    attemptsLeft: (data['attemptsLeft'] as num?)?.toInt(),
    retryAfterSeconds: (data['retryAfterSeconds'] as num?)?.toInt(),
  );
}

bool _isOffline(String code, Object? details) {
  if (code == 'unavailable' || code == 'deadline-exceeded') return true;
  // the ios plugin reports a dropped network as unknown with no details
  return defaultTargetPlatform == TargetPlatform.iOS &&
      code == 'unknown' &&
      details == null;
}

abstract class AuthCodeApi {
  Future<CodeResult> sendEmailVerificationCode(String locale);

  Future<CodeResult> verifyEmailCode(String code);

  Future<CodeResult> requestPasswordResetCode(String email, String locale);

  Future<CodeResult> verifyPasswordResetCode(String email, String code);

  Future<CodeResult> confirmPasswordReset({
    required String email,
    required String resetTicket,
    required String newPassword,
  });
}

class FunctionsAuthCodeApi implements AuthCodeApi {
  // the reset callables consume the app check token, so each call needs a fresh one
  static final _singleUseToken = HttpsCallableOptions(
    limitedUseAppCheckToken: true,
  );

  @override
  Future<CodeResult> sendEmailVerificationCode(String locale) =>
      _call('sendEmailVerificationCode', {'locale': locale});

  @override
  Future<CodeResult> verifyEmailCode(String code) =>
      _call('verifyEmailCode', {'code': code});

  @override
  Future<CodeResult> requestPasswordResetCode(String email, String locale) =>
      _call('requestPasswordResetCode', {
        'email': email,
        'locale': locale,
      }, options: _singleUseToken);

  @override
  Future<CodeResult> verifyPasswordResetCode(String email, String code) =>
      _call('verifyPasswordResetCode', {
        'email': email,
        'code': code,
      }, options: _singleUseToken);

  @override
  Future<CodeResult> confirmPasswordReset({
    required String email,
    required String resetTicket,
    required String newPassword,
  }) => _call('confirmPasswordReset', {
    'email': email,
    'resetTicket': resetTicket,
    'newPassword': newPassword,
  }, options: _singleUseToken);

  Future<CodeResult> _call(
    String name,
    Map<String, dynamic> input, {
    HttpsCallableOptions? options,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      name,
      options: options,
    );
    try {
      final result = await callable.call<Object?>(input);
      return CodeOk(Map<String, dynamic>.from(result.data as Map));
    } on FirebaseFunctionsException catch (e) {
      return codeFailureFor(e.code, e.details);
    }
  }
}
