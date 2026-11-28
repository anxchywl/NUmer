import 'dart:math';

import 'package:intl/intl.dart';

import 'package:numer_app/l10n/app_localizations.dart';

import 'models/feed_item.dart';

String newsMeta(AppLocalizations l10n, String locale, FeedItem item) {
  String date(DateTime at) => DateFormat.MMMd(locale).format(at.toLocal());
  if (item.kind == FeedKind.announcement) {
    return '${l10n.newsSourceNumer}, ${date(item.publishedAt)}';
  }
  final startsAt = item.startsAt;
  final place = item.place;
  return [
    l10n.newsKindEvent,
    if (startsAt != null) ...[
      date(startsAt),
      DateFormat.Hm(locale).format(startsAt.toLocal()),
    ],
    if (place != null && place.isNotEmpty) place,
  ].join(', ');
}

String newsUpdatedLine(AppLocalizations l10n, Duration age) {
  if (age.inMinutes < Duration.minutesPerHour) {
    return l10n.newsUpdatedMinutes(max(1, age.inMinutes));
  }
  return l10n.newsUpdatedHours(age.inHours);
}
