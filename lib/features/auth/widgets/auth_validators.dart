import 'package:flutter/services.dart';

import 'package:numer_app/l10n/app_localizations.dart';

const int emailMaxLength = 254;
const int passwordMinLength = 8;
const int passwordMaxLength = 64;
// allowed password chars: A-Z, a-z, 0-9 and the listed symbols
final allowedPasswordCharsRegex = RegExp(
  r'^[A-Za-z0-9!@#$%^&*()\-_=+\[\]{};:'
  "'"
  r'",.<>/?\\|~]*$',
);
final passwordInputFormatters = <TextInputFormatter>[
  LengthLimitingTextInputFormatter(passwordMaxLength),
  FilteringTextInputFormatter.allow(
    RegExp(
      r'[A-Za-z0-9!@#$%^&*()\-_=+\[\]{};:'
      "'"
      r'",.<>/?\\|~]',
    ),
  ),
];
final emailInputFormatters = <TextInputFormatter>[
  LengthLimitingTextInputFormatter(emailMaxLength),
  FilteringTextInputFormatter.allow(
    RegExp(
      r'[A-Za-z0-9!@#$%^&*()\-_=+\[\]{};:'
      "'"
      r'",.<>/?\\|~@.]',
    ),
  ),
];
final emailRegex = RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

bool hasInvalidPasswordChars(String value) {
  return !allowedPasswordCharsRegex.hasMatch(value);
}

// the rules a password must meet at registration and at reset
String? newPasswordError(AppLocalizations l10n, String? value) {
  if (value == null || value.length < passwordMinLength) {
    return l10n.passwordLength;
  }
  if (hasInvalidPasswordChars(value)) return l10n.passwordInvalidChars;
  return null;
}
