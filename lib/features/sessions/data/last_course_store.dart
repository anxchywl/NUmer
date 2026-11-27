import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LastCourseStore extends ChangeNotifier {
  LastCourseStore(this._prefs);

  static const _key = 'home_last_course_id_v1';

  final SharedPreferences _prefs;

  // may point to a course that was deleted since
  String? get id => _prefs.getString(_key);

  Future<void> save(String courseId) async {
    if (id == courseId) return;
    // the cached value changes before the write completes
    final write = _prefs.setString(_key, courseId);
    notifyListeners();
    await write;
  }
}
