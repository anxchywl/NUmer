import 'package:numer_app/core/data/local_database.dart';
import 'package:numer_app/core/data/storage.dart';
import 'package:numer_app/core/data/user_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool hasUnsyncedChanges(LocalDatabase db) =>
    (db.userDocOrNull?.dirty ?? false) ||
    db.dirtyCourses().isNotEmpty ||
    db.dirtySessions().isNotEmpty ||
    db.dirtyGoals().isNotEmpty ||
    db.dirtyHabits().isNotEmpty ||
    db.dirtyHabitHistory().isNotEmpty;

bool _isSessionPreference(String key) =>
    key.startsWith('timer_planned_') ||
    key.startsWith('progress_') ||
    key == 'onboarded_credits_v1' ||
    key == 'themeMode' ||
    key == 'device_id';

Future<void> _clearUserPreferences(String uid) async {
  UserStorage.setCurrentUser(uid);
  final userStorage = await UserStorage.getInstance();
  await userStorage.clearUserData();
  UserStorage.setCurrentUser(null);

  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getKeys().where(_isSessionPreference).toList();
  for (final key in keys) {
    await prefs.remove(key);
  }
  await prefs.remove('fcm_saved_token_$uid');
  await prefs.remove('fcm_saved_at_$uid');
}

// erase is false only for a sign-out with unsynced changes, which stay on the device for the next sign-in
Future<void> closeLocalUserData(String uid, {required bool erase}) async {
  await Storage.closeForSignOut();
  if (erase) await Storage.eraseUser(uid);
  await _clearUserPreferences(uid);
}
