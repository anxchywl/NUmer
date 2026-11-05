class PasswordResetResult {
  final bool success;
  final bool verificationRequired;
  final bool verificationEmailSent;
  final String message;
  final String? code;

  const PasswordResetResult({
    required this.success,
    required this.verificationRequired,
    required this.verificationEmailSent,
    required this.message,
    this.code,
  });
}
