enum AuthErrorKind {
  emailRequired,
  invalidEmail,
  displayNameRequired,
  passwordRequired,
  weakPassword,
  emailInUse,
  wrongCredentials,
  accountDisabled,
  tooManyAttempts,
  signInFailed,
  accountCreationFailed,
  notSignedIn,
  emailNotVerified,
  verificationCheckFailed,
  dataDownloadFailed,
}

AuthErrorKind authErrorKindFor(String code) {
  switch (code) {
    case 'email-already-in-use':
      return AuthErrorKind.emailInUse;
    case 'invalid-email':
      return AuthErrorKind.invalidEmail;
    case 'weak-password':
      return AuthErrorKind.weakPassword;
    case 'user-disabled':
      return AuthErrorKind.accountDisabled;
    case 'user-not-found':
    case 'wrong-password':
      return AuthErrorKind.wrongCredentials;
    case 'too-many-requests':
      return AuthErrorKind.tooManyAttempts;
    default:
      return AuthErrorKind.signInFailed;
  }
}
