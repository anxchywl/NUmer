import 'auth_code_api.dart';

mixin PasswordReset {
  AuthCodeApi get codeApi;

  Future<CodeResult> requestPasswordResetCode(String email, String locale) =>
      codeApi.requestPasswordResetCode(email, locale);

  Future<CodeResult> verifyPasswordResetCode(String email, String code) =>
      codeApi.verifyPasswordResetCode(email, code);

  Future<CodeResult> confirmPasswordReset(
    String email,
    String ticket,
    String newPassword,
  ) => codeApi.confirmPasswordReset(
    email: email,
    resetTicket: ticket,
    newPassword: newPassword,
  );
}
