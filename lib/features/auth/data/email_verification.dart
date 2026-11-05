import 'package:firebase_auth/firebase_auth.dart';

import 'auth_code_api.dart';

mixin EmailVerification {
  AuthCodeApi get codeApi;
  FirebaseAuth get firebaseAuth;
  Future<String?> checkEmailVerified();

  Future<CodeResult> sendVerificationCode(String locale) =>
      codeApi.sendEmailVerificationCode(locale);

  Future<CodeResult> verifyEmailCode(String code) async {
    final result = await codeApi.verifyEmailCode(code);
    if (result is! CodeOk) return result;
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
}
