import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:numer_app/core/data/local_database.dart';
import 'package:numer_app/core/data/storage.dart';
import 'package:numer_app/features/auth/data/local_user_data.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _boxes = [
  'user',
  'courses',
  'sessions',
  'goals',
  'sync',
  'conflicts',
  'meta',
  'peer_sessions',
  'peer_courses',
  'habits',
  'habit_history',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  var userCount = 0;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('local_user_data');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => directory.path,
        );
  });

  tearDownAll(() async {
    await Storage.closeForSignOut();
    await directory.delete(recursive: true);
  });

  Future<String> signedIn() async {
    final uid = 'local${userCount++}';
    await Storage.configureForUser(uid);
    return uid;
  }

  Future<List<bool>> boxesOf(String uid) =>
      Future.wait([for (final box in _boxes) Hive.boxExists('${uid}_$box')]);

  test('erasing deletes every box of the user and keeps other users', () async {
    final other = await signedIn();
    await Storage.closeForSignOut();
    final uid = await signedIn();

    await closeLocalUserData(uid, erase: true);

    expect(await boxesOf(uid), everyElement(isFalse));
    expect(await boxesOf(other), everyElement(isTrue));
  });

  test('keeping closes the boxes and leaves them on disk', () async {
    final uid = await signedIn();

    await closeLocalUserData(uid, erase: false);

    expect(await boxesOf(uid), everyElement(isTrue));
    expect(LocalDatabase.instance.currentUid, isNull);
  });

  test('clears the per-user preferences and keeps the rest', () async {
    final uid = await signedIn();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setInt('user_${uid}_lastTab', 2);
    await prefs.setString('fcm_saved_token_$uid', 'token');
    await prefs.setInt('fcm_saved_at_$uid', 1);
    await prefs.setString('email_index_written_$uid', 'a@x.test');
    await prefs.setString('timer_planned_1', 'x');
    await prefs.setString('themeMode', 'dark');
    await prefs.setInt('user_someone_lastTab', 1);

    await closeLocalUserData(uid, erase: true);

    expect(prefs.getKeys(), {'user_someone_lastTab'});
  });

  test('reports unsynced changes until they are pushed', () async {
    await signedIn();
    expect(hasUnsyncedChanges(LocalDatabase.instance), isFalse);

    await Storage.saveCourses([
      Course(
        id: 'c1',
        name: 'name',
        day: 'monday',
        start: '09:00',
        end: '10:00',
        colorValue: 0,
      ),
    ]);
    expect(hasUnsyncedChanges(LocalDatabase.instance), isTrue);

    for (final course in LocalDatabase.instance.coursesBox.values) {
      course.dirty = false;
      await course.save();
    }
    expect(hasUnsyncedChanges(LocalDatabase.instance), isFalse);
  });
}
