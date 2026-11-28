import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:numer_app/features/news/news_meta.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import 'news_fakes.dart';

void main() {
  setUpAll(initializeDateFormatting);

  final en = lookupAppLocalizations(const Locale('en'));
  final ru = lookupAppLocalizations(const Locale('ru'));

  test('an announcement names its source and date', () {
    expect(newsMeta(en, 'en', announcement('a')), 'NUmer, Nov 27');
  });

  test('an event names its date, time and place', () {
    expect(newsMeta(en, 'en', event('e')), 'Event, Dec 12, 18:00, Block C3');
  });

  test('a missing or empty place is dropped', () {
    for (final place in [null, '']) {
      expect(
        newsMeta(en, 'en', event('e', place: place)),
        'Event, Dec 12, 18:00',
      );
    }
  });

  test('russian uses the short month of the locale', () {
    final date = DateFormat.MMMd('ru').format(DateTime(2026, 11, 27));

    expect(date, contains('нояб.'));
    expect(newsMeta(ru, 'ru', announcement('a')), 'NUmer, $date');
  });

  test('the update line counts minutes, then hours', () {
    String line(Duration age) => newsUpdatedLine(en, age);

    expect(line(Duration.zero), 'Updated 1 min ago');
    expect(line(const Duration(minutes: 10)), 'Updated 10 min ago');
    expect(line(const Duration(minutes: 59)), 'Updated 59 min ago');
    expect(line(const Duration(hours: 2, minutes: 40)), 'Updated 2 h ago');
  });
}
