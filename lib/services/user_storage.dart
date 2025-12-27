import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';


class UserStorage {
  UserStorage._();
  static UserStorage? _instance;
  static String? _currentUserId;

  SharedPreferences? _prefs;
  bool _initialized = false;

  static Future<UserStorage> getInstance() async {
    if (_instance == null) {
      _instance = UserStorage._();
      await _instance!._init();
    }
    return _instance!;
  }

  Future<void> _init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  
  static void setCurrentUser(String? userId) {
    _currentUserId = userId;
  }

  
  String _getKey(String key) {
    if (_currentUserId == null) {
      throw StateError('No user is currently logged in');
    }
    return 'user_${_currentUserId}_$key';
  }

  
  bool containsKey(String key) {
    return _prefs?.containsKey(_getKey(key)) ?? false;
  }

  
  Future<bool> remove(String key) async {
    return await _prefs?.remove(_getKey(key)) ?? false;
  }

  
  String? getString(String key) {
    return _prefs?.getString(_getKey(key));
  }

  
  Future<bool> setString(String key, String value) async {
    return await _prefs?.setString(_getKey(key), value) ?? false;
  }

  
  bool? getBool(String key) {
    return _prefs?.getBool(_getKey(key));
  }

  
  Future<bool> setBool(String key, bool value) async {
    return await _prefs?.setBool(_getKey(key), value) ?? false;
  }

  
  int? getInt(String key) {
    return _prefs?.getInt(_getKey(key));
  }

  
  Future<bool> setInt(String key, int value) async {
    return await _prefs?.setInt(_getKey(key), value) ?? false;
  }

  
  double? getDouble(String key) {
    return _prefs?.getDouble(_getKey(key));
  }

  
  Future<bool> setDouble(String key, double value) async {
    return await _prefs?.setDouble(_getKey(key), value) ?? false;
  }

  
  List<String>? getStringList(String key) {
    return _prefs?.getStringList(_getKey(key));
  }

  
  Future<bool> setStringList(String key, List<String> value) async {
    return await _prefs?.setStringList(_getKey(key), value) ?? false;
  }

  
  Set<String> getUserKeys() {
    if (_currentUserId == null || _prefs == null) return {};
    final prefix = 'user_${_currentUserId}_';
    return _prefs!.getKeys()
        .where((key) => key.startsWith(prefix))
        .map((key) => key.substring(prefix.length))
        .toSet();
  }

  
  Future<void> clearUserData() async {
    if (_currentUserId == null || _prefs == null) return;
    final keys = getUserKeys();
    for (final key in keys) {
      await remove(key);
    }
  }

  
  Map<String, dynamic>? getJson(String key) {
    final value = getString(key);
    if (value == null) return null;
    try {
      return jsonDecode(value) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  
  Future<bool> setJson(String key, Map<String, dynamic> value) async {
    return await setString(key, jsonEncode(value));
  }
}