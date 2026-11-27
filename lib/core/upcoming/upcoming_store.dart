import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'upcoming_item.dart';

// personal items modules put on home, kept per user on this device and never synced
class UpcomingStore extends ChangeNotifier {
  UpcomingStore(this._prefs, {DateTime Function() now = DateTime.now})
    : _now = now;

  final SharedPreferences _prefs;
  final DateTime Function() _now;

  static String _key(String uid) => 'upcoming_v1_$uid';

  List<UpcomingItem> upcoming(String uid) {
    final now = _now();
    return _read(uid).where((item) => !item.startsAt.isBefore(now)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  Future<void> put(String uid, UpcomingItem item) {
    final now = _now();
    final items = [
      ..._read(uid).where((other) => other.id != item.id),
      item,
    ].where((other) => !other.startsAt.isBefore(now));
    return _write(uid, items);
  }

  Future<void> remove(String uid, String id) =>
      _write(uid, _read(uid).where((item) => item.id != id));

  Future<void> clear(String uid) async {
    await _prefs.remove(_key(uid));
    notifyListeners();
  }

  List<UpcomingItem> _read(String uid) {
    final raw = _prefs.getString(_key(uid));
    if (raw == null) return const [];
    final entries = jsonDecode(raw) as List<dynamic>;
    return entries.map(UpcomingItem.fromJson).nonNulls.toList();
  }

  Future<void> _write(String uid, Iterable<UpcomingItem> items) async {
    final encoded = jsonEncode([for (final item in items) item.toJson()]);
    await _prefs.setString(_key(uid), encoded);
    notifyListeners();
  }
}
