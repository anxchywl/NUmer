import 'package:flutter/widgets.dart';

import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/app_toast.dart';

import '../data/auth_error_kind.dart';

String authErrorText(AppLocalizations l10n, AuthErrorKind kind) {
  return switch (kind) {
    AuthErrorKind.emailRequired => l10n.enterEmail,
    AuthErrorKind.invalidEmail => l10n.invalidEmail,
    AuthErrorKind.displayNameRequired => l10n.displayNameLength,
    AuthErrorKind.passwordRequired => l10n.enterPassword,
    AuthErrorKind.weakPassword => l10n.passwordLength,
    AuthErrorKind.emailInUse => l10n.emailInUseHint,
    AuthErrorKind.wrongCredentials => l10n.authWrongCredentials,
    AuthErrorKind.accountDisabled => l10n.authAccountDisabled,
    AuthErrorKind.tooManyAttempts => l10n.authTooManyAttempts,
    AuthErrorKind.signInFailed => l10n.authSignInFailed,
    AuthErrorKind.accountCreationFailed => l10n.authAccountCreationFailed,
    AuthErrorKind.notSignedIn => l10n.authNotSignedIn,
    AuthErrorKind.emailNotVerified => l10n.authEmailNotVerified,
    AuthErrorKind.verificationCheckFailed => l10n.authVerificationCheckFailed,
    AuthErrorKind.dataDownloadFailed => l10n.authDataDownloadFailed,
  };
}

void showAuthError(BuildContext context, AuthErrorKind kind) {
  final l10n = AppLocalizations.of(context)!;
  showAppMessage(context, authErrorText(l10n, kind), isError: true);
}
