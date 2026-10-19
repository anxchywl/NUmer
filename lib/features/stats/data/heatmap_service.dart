import 'package:flutter/foundation.dart';
import 'package:numer_app/core/data/storage.dart';

class HeatmapService extends ChangeNotifier {
  static final HeatmapService _instance = HeatmapService._internal();
  factory HeatmapService() => _instance;

  HeatmapService._internal() {
    Storage.sessionUpdates.listen(_onSessionUpdates);
  }

  // Cache: MonthStart -> Daily Totals
  final Map<DateTime, Map<DateTime, int>> _cache = {};

  void _onSessionUpdates(List<DateTime> dates) {
    if (dates.isEmpty) return;

    // Invalidate cache for affected months
    bool changed = false;
    for (final date in dates) {
      final monthKey = DateTime(date.year, date.month, 1);
      if (_cache.containsKey(monthKey)) {
        _cache.remove(monthKey);
        changed = true;
      }
    }

    // Notify listeners so UI can re-fetch if needed
    if (changed) {
      notifyListeners();
    }
  }

  /// Fetches daily totals for the given month (and adjacent days if needed by calendar grid).
  /// To support lazy-loading "current month only", we expect [month] to be the 1st of the month.
  /// We will actually fetch a slight range around it or just the month.
  /// Given TableCalendar works with "focusedDay", we should probably cache by month.
  Future<Map<DateTime, int>> fetchMonth(DateTime month) async {
    final monthKey = DateTime(month.year, month.month, 1);

    if (_cache.containsKey(monthKey)) {
      return _cache[monthKey]!;
    }

    // Calculate range: First day of month to last day of month.
    // We strictly fetch this month's data.
    // If TableCalendar shows surrounding days, they will be fetched when "focusedDay" changes
    // OR we should perhaps fetch a bit more.
    // Requirement: "Load current month only".
    // "Update if changed day is in currently loaded month".

    final start = monthKey;
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final data = await Storage.getDailyTotals(start, end);
    _cache[monthKey] = data;
    return data;
  }
}
