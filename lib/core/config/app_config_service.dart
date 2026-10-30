import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:numer_app/core/config/app_config.dart';

// holds the remote app config, starting from the copy cached on this device
class AppConfigService extends ChangeNotifier {
  AppConfigService({
    required SharedPreferences prefs,
    required Future<Map<String, dynamic>?> Function() fetch,
    required int build,
  }) : _prefs = prefs,
       _fetch = fetch,
       _build = build {
    final cached = prefs.getString(_cacheKey);
    if (cached != null) _config = AppConfig.fromJson(cached);
  }

  static const _cacheKey = 'app_config_v1';
  static const _refreshInterval = Duration(hours: 6);

  final SharedPreferences _prefs;
  final Future<Map<String, dynamic>?> Function() _fetch;
  final int _build;

  AppConfig _config = AppConfig.defaults;
  AppConfig get config => _config;

  DateTime? _refreshedAt;

  bool get updateRequired => _build < _config.minSupportedBuild;

  bool isModuleVisible(String id, String uid) =>
      _config.isModuleVisible(id, uid: uid, build: _build);

  Future<void> refresh({bool force = false}) async {
    final refreshedAt = _refreshedAt;
    if (!force &&
        refreshedAt != null &&
        DateTime.now().difference(refreshedAt) < _refreshInterval) {
      return;
    }
    final Map<String, dynamic>? data;
    try {
      data = await _fetch();
    } on FirebaseException {
      // offline or denied, the current value stays
      return;
    }
    final next = AppConfig.fromMap(data);
    final encoded = next.toJson();
    final changed = encoded != _config.toJson();
    _config = next;
    _refreshedAt = DateTime.now();
    await _prefs.setString(_cacheKey, encoded);
    if (changed) notifyListeners();
  }
}
