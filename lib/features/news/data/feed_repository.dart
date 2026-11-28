import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/feed_item.dart';

class FeedRepository extends ChangeNotifier {
  FeedRepository({
    required SharedPreferences prefs,
    required Future<Map<String, dynamic>?> Function() fetch,
    DateTime Function() now = DateTime.now,
  }) : _prefs = prefs,
       _fetch = fetch,
       _now = now {
    _readCache();
  }

  static const _cacheKey = 'news_feed_v1';
  static const _refreshInterval = Duration(minutes: 30);

  final SharedPreferences _prefs;
  final Future<Map<String, dynamic>?> Function() _fetch;
  final DateTime Function() _now;

  List<FeedItem> _items = const [];
  List<FeedItem> get items => _items;

  DateTime? _fetchedAt;
  DateTime? get fetchedAt => _fetchedAt;

  bool _lastRefreshFailed = false;
  bool get lastRefreshFailed => _lastRefreshFailed;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool get _isFresh {
    final fetchedAt = _fetchedAt;
    if (fetchedAt == null) return false;
    final age = _now().difference(fetchedAt);
    // a clock set back must not freeze the feed
    return !age.isNegative && age < _refreshInterval;
  }

  Future<void> refresh({bool force = false}) async {
    if (_isLoading || (!force && _isFresh)) return;
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _fetch();
      _items = _parseItems(data?['items'], FeedItem.fromFirestore);
      _fetchedAt = _now();
      _lastRefreshFailed = false;
      await _writeCache();
    } on FirebaseException {
      // offline or denied, the cached items stay
      _lastRefreshFailed = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _readCache() {
    final cached = _prefs.getString(_cacheKey);
    if (cached == null) return;
    final Object? json;
    try {
      json = jsonDecode(cached);
    } on FormatException {
      // a damaged cache is the same as none
      return;
    }
    if (json is! Map || json['fetchedAt'] is! int) return;
    _fetchedAt = DateTime.fromMillisecondsSinceEpoch(json['fetchedAt'] as int);
    _items = _parseItems(json['items'], FeedItem.fromJson);
  }

  Future<void> _writeCache() => _prefs.setString(
    _cacheKey,
    jsonEncode({
      'fetchedAt': _fetchedAt!.millisecondsSinceEpoch,
      'items': [for (final item in _items) item.toJson()],
    }),
  );
}

List<FeedItem> _parseItems(
  Object? raw,
  FeedItem Function(Map<String, dynamic>) parse,
) {
  if (raw is! List) return const [];
  final items = <FeedItem>[];
  for (final entry in raw.whereType<Map<dynamic, dynamic>>()) {
    try {
      items.add(parse(Map<String, dynamic>.from(entry)));
    } on FormatException {
      continue;
    }
  }
  return List.unmodifiable(items);
}
