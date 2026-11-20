import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/l10n/app_localizations.dart';

const courseColorChoices = <Color>[
  Color(0xFFEF4444), // Red
  Color(0xFFF97316), // Orange
  Color(0xFFFACC15), // Yellow
  Color(0xFF22C55E), // Green
  Color(0xFF3B82F6), // Blue
  Color(0xFF6366F1), // Indigo
  Color(0xFF8B5CF6), // Violet
  Color(0xFF84CC16), // Lime
  Color(0xFF14B8A6), // Teal
  Color(0xFF06B6D4), // Cyan
  Color(0xFFA855F7), // Purple
  Color(0xFFD946EF), // Magenta
  Color(0xFFEC4899), // Pink
];

double hoursPerCreditForLevel(int level) {
  switch (level) {
    case 1:
      return 3.0;
    case 2:
      return 2.5;
    case 3:
      return 2.0;
    case 4:
      return 1.5;
    case 5:
      return 1.0;
    default:
      return 2.0;
  }
}

String expShortLabel(BuildContext context, int level) {
  switch (level) {
    case 1:
      return AppLocalizations.of(context)!.expLevel1;
    case 2:
      return AppLocalizations.of(context)!.expLevel2;
    case 3:
      return AppLocalizations.of(context)!.expLevel3;
    case 4:
      return AppLocalizations.of(context)!.expLevel4;
    case 5:
      return AppLocalizations.of(context)!.expLevel5;
    default:
      return AppLocalizations.of(context)!.expLevelDefault;
  }
}

String formatHms(int s) {
  final h = (s ~/ 3600).toString().padLeft(2, '0');
  final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
  final sec = (s % 60).toString().padLeft(2, '0');
  return '$h:$m:$sec';
}

String courseNameWithoutParentheses(String value) {
  return value.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
}

Future<int> weeklyElapsedForCourse(BuildContext context, String id) async {
  final s = context.read<AppState>();
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day);
  final offset = s.weekStart == WeekStart.monday
      ? (midnight.weekday - DateTime.monday).clamp(0, 6)
      : (midnight.weekday % 7);
  final DateTime weekStart = midnight.subtract(Duration(days: offset));
  final DateTime weekEnd = weekStart.add(const Duration(days: 7));
  final map = await s.secondsByCourseBetween(weekStart, weekEnd);
  return map[id] ?? 0;
}
