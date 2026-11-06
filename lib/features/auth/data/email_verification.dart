import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_code_api.dart';

mixin EmailVerification {
  AuthCodeApi get codeApi;
  FirebaseAuth get firebaseAuth;
  Future<String?> checkEmailVerified();

  Future<CodeResult> sendVerificationCode(String locale) async {
    final uid = firebaseAuth.currentUser?.uid;
    final result = await codeApi.sendEmailVerificationCode(locale);
    if (uid == null) return result;
    switch (result) {
      case CodeOk():
        await _rememberCode(uid, result);
      // the server drops the previous code before it refuses or fails a send
      case CodeFailure(reason: CodeFailureReason.rateLimited):
      case CodeFailure(reason: CodeFailureReason.deliveryFailed):
        await _forgetCode(uid);
      case CodeFailure():
        break;
    }
    return result;
  }

  // null when no code was sent or the last one has expired
  Future<CodeOk?> pendingVerificationCode() async {
    final uid = firebaseAuth.currentUser?.uid;
    if (uid == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final expiresAt = prefs.getInt(_expiresKey(uid)) ?? 0;
    if (expiresAt <= DateTime.now().millisecondsSinceEpoch) return null;
    return CodeOk({
      'status': 'cooldown',
      'resendAvailableAt': prefs.getInt(_resendKey(uid)),
    });
  }

  Future<CodeResult> verifyEmailCode(String code) async {
    final uid = firebaseAuth.currentUser?.uid;
    final result = await codeApi.verifyEmailCode(code);
    if (result is! CodeOk) {
      if (uid != null && _endsCode(result)) await _forgetCode(uid);
      return result;
    }
    return await refreshVerifiedEmail() ?? result;
  }

  // the gate advances only once the session itself reports a verified address
  Future<CodeFailure?> refreshVerifiedEmail() async {
    try {
      await firebaseAuth.currentUser?.getIdToken(true);
    } on FirebaseAuthException catch (e) {
      return CodeFailure(
        e.code == 'network-request-failed'
            ? CodeFailureReason.offline
            : CodeFailureReason.unknown,
      );
    }
    final error = await checkEmailVerified();
    if (error == null) return null;
    return const CodeFailure(CodeFailureReason.unknown);
  }

  bool _endsCode(CodeResult result) {
    if (result is! CodeFailure) return false;
    return switch (result.reason) {
      CodeFailureReason.codeExpired ||
      CodeFailureReason.noActiveCode ||
      CodeFailureReason.tooManyAttempts => true,
      CodeFailureReason.invalidCode => result.attemptsLeft == 0,
      _ => false,
    };
  }

  String _expiresKey(String uid) => 'verify_code_expires_$uid';

  String _resendKey(String uid) => 'verify_code_resend_$uid';

  Future<void> _rememberCode(String uid, CodeOk sent) async {
    final expiresAt = sent.data['expiresAt'];
    final resendAvailableAt = sent.data['resendAvailableAt'];
    if (expiresAt is! num || resendAvailableAt is! num) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_expiresKey(uid), expiresAt.toInt());
    await prefs.setInt(_resendKey(uid), resendAvailableAt.toInt());
  }

  Future<void> _forgetCode(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_expiresKey(uid));
    await prefs.remove(_resendKey(uid));
  }
}
