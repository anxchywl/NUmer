import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/l10n/app_localizations.dart';

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    test('every kind has text in ${locale.languageCode}', () {
      final l10n = lookupAppLocalizations(locale);

      for (final kind in AuthErrorKind.values) {
        expect(authErrorText(l10n, kind), isNotEmpty, reason: kind.name);
      }
    });
  }

  test('a registered address maps to the sign in or reset hint', () {
    final l10n = lookupAppLocalizations(
      AppLocalizations.supportedLocales.first,
    );
    final kind = authErrorKindFor('email-already-in-use');

    expect(kind, AuthErrorKind.emailInUse);
    expect(authErrorText(l10n, kind), l10n.emailInUseHint);
  });

  test('an unlisted code maps to the general failure', () {
    expect(
      authErrorKindFor('network-request-failed'),
      AuthErrorKind.signInFailed,
    );
  });
}
