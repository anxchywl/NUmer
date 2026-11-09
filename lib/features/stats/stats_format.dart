import 'package:flutter/widgets.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import 'models/stats_models.dart';

TimeUnit pickUnit(int totalSeconds) {
  if (totalSeconds < 60) return TimeUnit.seconds;
  if (totalSeconds < 3600) return TimeUnit.minutes;
  return TimeUnit.hours;
}

double scaleForUnit(TimeUnit u) {
  switch (u) {
    case TimeUnit.seconds:
      return 1;
    case TimeUnit.minutes:
      return 60;
    case TimeUnit.hours:
      return 3600;
  }
}

String unitLabel(TimeUnit u, BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  switch (u) {
    case TimeUnit.seconds:
      return l10n.seconds_plural;
    case TimeUnit.minutes:
      return l10n.minutes_plural;
    case TimeUnit.hours:
      return l10n.hours_plural;
  }
}

String fmtAxisTick(double v, TimeUnit u) {
  String numStr;
  if (v == 0 || v.abs() >= 10) {
    numStr = v.toStringAsFixed(0);
  } else if ((v * 10).round() % 10 == 0) {
    numStr = v.toStringAsFixed(0);
  } else if ((v * 2).round() % 2 == 0) {
    numStr = v.toStringAsFixed(1);
  } else {
    numStr = v.toStringAsFixed(2);
  }
  return numStr;
}

double niceInterval(double maxY) {
  if (maxY <= 1) return 0.2;
  if (maxY <= 2) return 0.5;
  if (maxY <= 5) return 1.0;
  if (maxY <= 10) return 2.0;
  if (maxY <= 20) return 5.0;
  if (maxY <= 50) return 10.0;
  return 20.0;
}

String fmtHMS(int s) {
  final h = (s ~/ 3600).toString().padLeft(2, '0');
  final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
  final sec = (s % 60).toString().padLeft(2, '0');
  return '$h:$m:$sec';
}

String _shortTimeLabel(int seconds, BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  if (seconds >= 3600) return '${(seconds / 3600).round()}${l10n.hUnit}';
  if (seconds >= 60) return '${(seconds / 60).round()}${l10n.mUnit}';
  return '$seconds${l10n.sUnit}';
}

String pieSectionTitle(String name, int seconds, BuildContext context) {
  final timeLabel = _shortTimeLabel(seconds, context);
  final trimmed = name.trim();
  if (trimmed.isEmpty) return timeLabel;

  const maxLine = 12;
  if (trimmed.length <= maxLine) return '$trimmed\n$timeLabel';

  final split = _bestSplitIndex(trimmed);
  String line1;
  String line2;
  if (split > 0 && split < trimmed.length - 1) {
    line1 = trimmed.substring(0, split).trimRight();
    line2 = trimmed.substring(split).trimLeft();
  } else {
    final mid = trimmed.length ~/ 2;
    line1 = trimmed.substring(0, mid).trimRight();
    line2 = trimmed.substring(mid).trimLeft();
  }

  if (line2.isEmpty) return '$line1\n$timeLabel';
  return '$line1\n$line2\n$timeLabel';
}

int _bestSplitIndex(String value) {
  final mid = value.length ~/ 2;
  final left = value.lastIndexOf(' ', mid);
  final right = value.indexOf(' ', mid + 1);
  if (left == -1 && right == -1) return mid;
  if (left == -1) return right;
  if (right == -1) return left;
  return (mid - left) <= (right - mid) ? left : right;
}

String fmtTotalVerbose(int s, BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  final parts = <String>[];
  if (h > 0) parts.add('$h ${h == 1 ? l10n.hour : l10n.hours_plural}');
  if (m > 0) parts.add('$m ${m == 1 ? l10n.minute : l10n.minutes_plural}');
  if (sec > 0 || parts.isEmpty) {
    parts.add('$sec ${sec == 1 ? l10n.second : l10n.seconds_plural}');
  }
  return '${parts.join(" ")} ${l10n.total.toLowerCase()}';
}

String fmtDateShort(DateTime d, BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final mo = [
    l10n.jan,
    l10n.feb,
    l10n.mar,
    l10n.apr,
    l10n.may,
    l10n.jun,
    l10n.jul,
    l10n.aug,
    l10n.sep,
    l10n.oct,
    l10n.nov,
    l10n.dec,
  ];
  final i = (d.month - 1);
  final safe = i < 0 ? 0 : (i > 11 ? 11 : i);
  return '${mo[safe]} ${d.day}';
}

String fmtDateLong(DateTime d, BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final mo = [
    l10n.jan,
    l10n.feb,
    l10n.mar,
    l10n.apr,
    l10n.may,
    l10n.jun,
    l10n.jul,
    l10n.aug,
    l10n.sep,
    l10n.oct,
    l10n.nov,
    l10n.dec,
  ];
  final i = (d.month - 1);
  final safe = i < 0 ? 0 : (i > 11 ? 11 : i);
  return '${mo[safe]} ${d.day}, ${d.year}';
}

String monthName(BuildContext context, int m) {
  final l10n = AppLocalizations.of(context)!;
  switch (m) {
    case 1:
      return l10n.january;
    case 2:
      return l10n.february;
    case 3:
      return l10n.march;
    case 4:
      return l10n.april;
    case 5:
      return l10n.may;
    case 6:
      return l10n.june;
    case 7:
      return l10n.july;
    case 8:
      return l10n.august;
    case 9:
      return l10n.september;
    case 10:
      return l10n.october;
    case 11:
      return l10n.november;
    case 12:
      return l10n.december;
    default:
      return '';
  }
}

String prevLabel(BuildContext context, Range r) {
  final l10n = AppLocalizations.of(context)!;
  switch (r) {
    case Range.week:
      return l10n.previousWeek;
    case Range.month:
      return l10n.previousMonth;
    case Range.year:
      return l10n.previousYear;
  }
}

String nextLabel(BuildContext context, Range r) {
  final l10n = AppLocalizations.of(context)!;
  switch (r) {
    case Range.week:
      return l10n.nextWeek;
    case Range.month:
      return l10n.nextMonth;
    case Range.year:
      return l10n.nextYear;
  }
}
