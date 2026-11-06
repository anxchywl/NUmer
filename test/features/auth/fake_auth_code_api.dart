import 'package:numer_app/features/auth/auth.dart';

class FakeAuthCodeApi implements AuthCodeApi {
  final List<String> sentLocales = [];
  final List<String> checkedCodes = [];
  CodeResult sendResult = const CodeOk({'status': 'sent'});
  CodeResult verifyResult = const CodeOk({'verified': true});

  @override
  Future<CodeResult> sendEmailVerificationCode(String locale) async {
    sentLocales.add(locale);
    return sendResult;
  }

  @override
  Future<CodeResult> verifyEmailCode(String code) async {
    checkedCodes.add(code);
    return verifyResult;
  }

  @override
  Future<CodeResult> requestPasswordResetCode(
    String email,
    String locale,
  ) async => sendResult;

  @override
  Future<CodeResult> verifyPasswordResetCode(String email, String code) async =>
      verifyResult;

  @override
  Future<CodeResult> confirmPasswordReset({
    required String email,
    required String resetTicket,
    required String newPassword,
  }) async => verifyResult;
}
