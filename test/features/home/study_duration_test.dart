import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/home/study_duration.dart';
import 'package:numer_app/l10n/app_localizations.dart';

void main() {
  for (final (language, expected) in [
    ('en', ['0 min', '45 min', '1 h', '1 h 20 min']),
    ('ru', ['0 мин', '45 мин', '1 ч', '1 ч 20 мин']),
  ]) {
    test('formats study time in $language', () {
      final l10n = lookupAppLocalizations(Locale(language));

      expect([
        for (final seconds in [0, 45 * 60 + 59, 3600, 80 * 60])
          formatStudyDuration(l10n, seconds),
      ], expected);
    });
  }
}
