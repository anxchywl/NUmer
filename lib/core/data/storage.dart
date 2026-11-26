import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:hive/hive.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:numer_app/core/data/entities.dart';
import 'package:numer_app/core/data/local_database.dart';
import 'package:numer_app/features/sessions/models/alarm_item.dart';
import 'package:numer_app/features/courses/course.dart';
import 'package:numer_app/features/habits/models/habit_category.dart';

// static facade over the hive local database, primary read/write api for local models
class Storage {
  Storage._();

  static final LocalDatabase _db = LocalDatabase.instance;

  static const _metaDailyState = 'daily_state_v1';
  static const _metaCourseMinutes = 'course_minutes_v1';
  static const _metaActiveSession = 'active_session_v1';
  static const _metaTimerState = 'timer_state_v1';
  static const _metaLegacyDailyMigrated = 'legacy_daily_state_migrated_v1';
  static const _metaAlarms = 'alarms_v1';
  static const _metaProfileComplete = 'profile_complete_v1';
  static const _metaProfilePromptShown = 'profile_prompt_shown_v1';
  static const _metaLocale = 'locale_v1';
  static const _metaHabitCategories = 'habit_categories_v1';
  static const _metaLastExportMonth = 'last_export_month_v1';
  static const _metaBootstrapVersion = LocalDatabase.bootstrapMetaKey;
  static const _metaStreakSnapshot = LocalDatabase.streakMetaKey;
  static const _metaAccentColor = 'accent_color_v1';
  static const _metaUserColorPresets = 'user_color_presets_v1';
  static const _metaThemeMode = 'theme_mode_v2';
  static const _metaWeekStart = 'week_start_v2';
  static const _metaHomeSummaryRange = 'home_summary_range_v2';
  static const _metaProgressView = 'progress_view_v2';
  static const _metaQuickNotesEnabled = 'quick_notes_enabled_v2';
  static const _metaAllowNudges = 'allow_nudges_v2';
  static const _metaEisenhowerMatrixEnabled = 'eisenhower_matrix_enabled_v2';
  static const _metaSessionNotificationsEnabled = 'session_notifs_enabled_v2';
  static const int bootstrapVersion = 1;

  static Future<void> configureForUser(String uid) async {
    await _db.openForUser(uid);
  }

  static Future<void> closeForSignOut() async {
    await _db.close();
  }

  static Future<void> eraseUser(String uid) async {
    await _db.deleteBoxesForUser(uid);
  }

  static Future<void> clearAll() async {
    await _db.clearAll();
  }

  static void _ensureUser() {
    if (_db.currentUid == null) {
      throw StateError('Storage accessed without configuring user');
    }
  }

  static int _now() => DateTime.now().toUtc().millisecondsSinceEpoch;

  static LocalUserDoc _userDoc() {
    _ensureUser();
    return _db.ensureUserDoc();
  }

  static Future<void> _saveUser(LocalUserDoc doc, {bool dirty = true}) async {
    if (dirty) {
      doc.dirty = true;
      doc.updatedAtMs = _now();
    }
    await _db.putUser(doc);
  }

  static final _sessionUpdateController =
      StreamController<List<DateTime>>.broadcast();
  static Stream<List<DateTime>> get sessionUpdates =>
      _sessionUpdateController.stream;

  static Future<String?> getMajor() async => _userDoc().major;

  static Future<void> setMajor(String? major) async {
    final doc = _userDoc();
    doc.major = (major == null || major.trim().isEmpty) ? null : major.trim();
    await _saveUser(doc);
  }

  static Future<String?> getProfileName() async => _userDoc().profileName;

  static Future<void> setProfileName(String? name) async {
    final doc = _userDoc();
    doc.profileName = (name == null || name.trim().isEmpty)
        ? null
        : name.trim();
    await _saveUser(doc);
    if (name != null && name.trim().isNotEmpty) {
      await _db.putMeta(_metaProfileComplete, true);
    }
  }

  static Future<bool> hasCompletedProfileSetup() async {
    _ensureUser();
    return _db.getMeta(_metaProfileComplete) == true;
  }

  static Future<String?> getProfileGoal() async => _userDoc().profileGoal;

  static Future<void> setProfileGoal(String? goal) async {
    final doc = _userDoc();
    doc.profileGoal = (goal == null || goal.trim().isEmpty)
        ? null
        : goal.trim();
    await _saveUser(doc);
  }

  static Future<String?> getProfileContact() async => _userDoc().profileContact;

  static Future<void> setProfileContact(String? contact) async {
    final doc = _userDoc();
    doc.profileContact = (contact == null || contact.trim().isEmpty)
        ? null
        : contact.trim();
    await _saveUser(doc);
  }

  static Future<int?> getProfileAvatarIndex() async => _userDoc().avatarIndex;

  static Future<void> setProfileAvatarIndex(int? index) async {
    final doc = _userDoc();
    doc.avatarIndex = index != null && index >= 0 ? index : null;
    await _saveUser(doc);
  }

  static Future<Uint8List?> getProfileAvatarImageBytes() async =>
      _userDoc().avatarImage;

  static Future<void> setProfileAvatarImageBytes(Uint8List? bytes) async {
    final doc = _userDoc();
    doc.avatarImage = (bytes == null || bytes.isEmpty)
        ? null
        : Uint8List.fromList(bytes);
    await _saveUser(doc);
  }

  static Future<int?> getProfileAvatarColor() async =>
      _userDoc().avatarColorValue;

  static Future<void> setProfileAvatarColor(int? value) async {
    final doc = LocalDatabase.instance.ensureUserDoc();
    doc.avatarColorValue = value;
    doc.dirty = true;
    await doc.save();
  }

  static bool getProfileComplete() {
    return LocalDatabase.instance.userDocOrNull?.profileComplete ?? false;
  }

  static Future<void> setProfileComplete(bool value) async {
    final doc = LocalDatabase.instance.ensureUserDoc();
    doc.profileComplete = value;
    doc.dirty = true;
    await doc.save();
  }

  static Future<bool> getOnboardingCompleted() async {
    return _userDoc().onboardingCompleted;
  }

  static Future<void> setOnboardingCompleted(bool value) async {
    final doc = _userDoc();
    doc.onboardingCompleted = value;
    await _saveUser(doc);
  }

  static Future<int?> getBootstrapVersionFlag() async {
    _ensureUser();
    final raw = _db.getMeta(_metaBootstrapVersion);
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return _userDoc().bootstrapVersion;
  }

  static Future<void> setBootstrapVersionFlag(int version) async {
    _ensureUser();
    await _db.putMeta(_metaBootstrapVersion, version);
    final doc = _userDoc();
    doc.bootstrapVersion = version;
    doc.dirty = true;
    await doc.save();
  }

  static Future<String?> getThemeMode() async {
    if (_db.currentUid == null) return null;
    final raw = _db.getMeta(_metaThemeMode);
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim();
    }
    final docMode = _userDoc().themeMode;
    if (docMode != null && docMode.trim().isNotEmpty) {
      final normalized = docMode.trim();
      await _db.putMeta(_metaThemeMode, normalized);
      return normalized;
    }
    return null;
  }

  static Future<void> setThemeMode(String? mode) async {
    if (_db.currentUid == null) return;
    final doc = _userDoc();
    final normalized = (mode == null || mode.trim().isEmpty)
        ? null
        : mode.trim();
    await _db.putMeta(_metaThemeMode, normalized);
    doc.themeMode = normalized;
    await _saveUser(doc, dirty: false);
  }

  static Future<int?> getAccentColor() async {
    if (_db.currentUid == null) return null;
    final val = _db.getMeta(_metaAccentColor);
    if (val is int) return val;
    return null;
  }

  static Future<void> setAccentColor(int colorValue) async {
    if (_db.currentUid == null) return;
    await _db.putMeta(_metaAccentColor, colorValue);
  }

  static List<Map<String, dynamic>> getUserColorPresets() {
    _ensureUser();
    final raw = _db.getMeta(_metaUserColorPresets);
    if (raw is List) {
      return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    return [];
  }

  static Future<void> saveUserColorPresets(
    List<Map<String, dynamic>> presets,
  ) async {
    _ensureUser();
    await _db.putMeta(_metaUserColorPresets, presets);
  }

  static Future<bool> getProfilePromptShown() async {
    _ensureUser();
    return _db.getMeta(_metaProfilePromptShown) == true;
  }

  static Future<void> setProfilePromptShown(bool value) async {
    _ensureUser();
    await _db.putMeta(_metaProfilePromptShown, value);
  }

  static Future<bool> getPendingCoursePrompt() async =>
      _userDoc().pendingCoursePrompt;

  static Future<void> setPendingCoursePrompt(bool value) async {
    final doc = _userDoc();
    doc.pendingCoursePrompt = value;
    await _saveUser(doc, dirty: value);
  }

  static Future<String> getWeekStart() async {
    _ensureUser();
    final raw = _db.getMeta(_metaWeekStart);
    if (raw is String) {
      final normalized = raw == 'sunday' ? 'sunday' : 'monday';
      if (normalized != raw) {
        await _db.putMeta(_metaWeekStart, normalized);
      }
      return normalized;
    }
    final doc = _userDoc();
    final normalized = doc.weekStart == 'sunday' ? 'sunday' : 'monday';
    await _db.putMeta(_metaWeekStart, normalized);
    return normalized;
  }

  static Future<void> setWeekStart(String value) async {
    _ensureUser();
    final normalized = (value == 'sunday') ? 'sunday' : 'monday';
    await _db.putMeta(_metaWeekStart, normalized);
    final doc = _userDoc();
    doc.weekStart = normalized;
    await _saveUser(doc, dirty: false);
  }

  static Future<String> getHomeSummaryRange() async {
    _ensureUser();
    final raw = _db.getMeta(_metaHomeSummaryRange);
    const allowed = {'today', 'week', 'month', 'year', 'allTime', 'off'};
    if (raw is String && allowed.contains(raw)) {
      return raw;
    }
    final docValue = _userDoc().homeSummaryRange;
    final normalized = allowed.contains(docValue) ? docValue : 'today';
    await _db.putMeta(_metaHomeSummaryRange, normalized);
    return normalized;
  }

  static Future<void> setHomeSummaryRange(String value) async {
    _ensureUser();
    const allowed = {'today', 'week', 'month', 'year', 'allTime', 'off'};
    final normalized = allowed.contains(value) ? value : 'today';
    await _db.putMeta(_metaHomeSummaryRange, normalized);
    final doc = _userDoc();
    doc.homeSummaryRange = normalized;
    await _saveUser(doc, dirty: false);
  }

  static Future<String> getProgressView() async {
    _ensureUser();
    final raw = _db.getMeta(_metaProgressView);
    const allowed = {'week', 'day', 'off'};
    if (raw is String && allowed.contains(raw)) {
      return raw;
    }
    final docValue = _userDoc().progressView;
    final normalized = allowed.contains(docValue) ? docValue : 'week';
    await _db.putMeta(_metaProgressView, normalized);
    return normalized;
  }

  static Future<void> setProgressView(String value) async {
    _ensureUser();
    const allowed = {'week', 'day', 'off'};
    final normalized = allowed.contains(value) ? value : 'week';
    await _db.putMeta(_metaProgressView, normalized);
    final doc = _userDoc();
    doc.progressView = normalized;
    await _saveUser(doc, dirty: false);
  }

  static Future<bool> getQuickNotesEnabled() async {
    _ensureUser();
    final raw = _db.getMeta(_metaQuickNotesEnabled);
    if (raw is bool) return raw;
    final fallback = _userDoc().quickNotesEnabled;
    await _db.putMeta(_metaQuickNotesEnabled, fallback);
    return fallback;
  }

  static Future<void> setQuickNotesEnabled(bool value) async {
    _ensureUser();
    await _db.putMeta(_metaQuickNotesEnabled, value);
    final doc = _userDoc();
    doc.quickNotesEnabled = value;
    await _saveUser(doc, dirty: false);
  }

  static Future<bool> getAllowNudges() async {
    _ensureUser();
    final raw = _db.getMeta(_metaAllowNudges);
    if (raw is bool) return raw;
    final fallback = _userDoc().allowNudges;
    await _db.putMeta(_metaAllowNudges, fallback);
    return fallback;
  }

  static Future<void> setAllowNudges(bool value) async {
    _ensureUser();
    await _db.putMeta(_metaAllowNudges, value);
    final doc = _userDoc();
    doc.allowNudges = value;
    await _saveUser(doc, dirty: true);
  }

  static Future<bool> getEisenhowerMatrixEnabled() async {
    _ensureUser();
    final raw = _db.getMeta(_metaEisenhowerMatrixEnabled);
    if (raw is bool) return raw;
    final fallback = _userDoc().eisenhowerMatrixEnabled;
    await _db.putMeta(_metaEisenhowerMatrixEnabled, fallback);
    return fallback;
  }

  static Future<void> setEisenhowerMatrixEnabled(bool value) async {
    _ensureUser();
    await _db.putMeta(_metaEisenhowerMatrixEnabled, value);
    final doc = _userDoc();
    doc.eisenhowerMatrixEnabled = value;
    await _saveUser(doc, dirty: false);
  }

  static Future<bool> getSessionNotificationsEnabled() async {
    _ensureUser();
    final raw = _db.getMeta(_metaSessionNotificationsEnabled);
    if (raw is bool) return raw;
    final fallback = _userDoc().sessionNotificationsEnabled;
    await _db.putMeta(_metaSessionNotificationsEnabled, fallback);
    return fallback;
  }

  static Future<void> setSessionNotificationsEnabled(bool value) async {
    _ensureUser();
    await _db.putMeta(_metaSessionNotificationsEnabled, value);
    final doc = _userDoc();
    doc.sessionNotificationsEnabled = value;
    await _saveUser(doc, dirty: false);
  }

  // eisenhower matrix quadrant placements, local-only and not synced
  static const _metaHabitQuadrants = 'habit_quadrants_v1';

  /// habit → quadrant mapping, 0-3 for quadrants or null when unsorted
  static Map<String, int> getHabitQuadrantPlacements() {
    _ensureUser();
    final raw = _db.getMeta(_metaHabitQuadrants);
    if (raw is Map) {
      return raw.map<String, int>(
        (key, value) => MapEntry(key.toString(), (value as num).toInt()),
      );
    }
    return {};
  }

  /// save a habit → quadrant placement, quadrant 0-3
  static Future<void> saveHabitQuadrantPlacement(
    String habitId,
    int quadrant,
  ) async {
    _ensureUser();
    final placements = getHabitQuadrantPlacements();
    placements[habitId] = quadrant.clamp(0, 3);
    await _db.putMeta(_metaHabitQuadrants, placements);
  }

  /// remove a habit from the quadrant placements
  static Future<void> removeHabitFromQuadrant(String habitId) async {
    _ensureUser();
    final placements = getHabitQuadrantPlacements();
    if (placements.containsKey(habitId)) {
      placements.remove(habitId);
      await _db.putMeta(_metaHabitQuadrants, placements);
    }
  }

  static Future<String?> getLocale() async {
    _ensureUser();
    return _db.getMeta(_metaLocale) as String?;
  }

  static Future<void> setLocale(String? localeName) async {
    if (_db.currentUid == null) return; // skip if no user configured
    await _db.putMeta(_metaLocale, localeName);
  }

  static List<Course> _mapCourses(Iterable<LocalCourse> source) {
    return source
        .where((c) => !c.deleted)
        .map(
          (c) => Course(
            id: c.id,
            name: c.name,
            day: c.day,
            start: c.start,
            end: c.end,
            colorValue: c.colorValue,
            credits: c.credits,
            expLevel: c.expLevel,
            sortOrder: c.sortOrder,
            hiddenFromLeaderboard: c.hiddenFromLeaderboard,
          ),
        )
        .toList();
  }

  static Future<List<Course>> getCourses() async {
    _ensureUser();
    final items = _db.courses().toList();
    await _ensureCourseOrder(items);
    final courses = _mapCourses(items);
    courses.sort(_compareCourseOrder);
    return courses;
  }

  static Future<void> saveCourses(List<Course> courses) async {
    _ensureUser();
    final box = _db.coursesBox;
    final uid = _db.currentUid!;
    final now = _now();
    final incomingIds = {for (final c in courses) c.id};

    for (final entry in box.values) {
      if (!incomingIds.contains(entry.id) && !entry.deleted) {
        entry.deleted = true;
        entry.dirty = true;
        entry.updatedAtMs = now;
        await entry.save();
      }
    }

    for (final course in courses) {
      final existing = box.get(course.id);
      if (existing == null) {
        final created = LocalCourse(
          id: course.id,
          uid: uid,
          updatedAtMs: now,
          name: course.name,
          day: course.day,
          start: course.start,
          end: course.end,
          colorValue: course.colorValue,
          credits: course.credits,
          expLevel: course.expLevel,
          goalHours: _db.getGoalById(course.id)?.hours,
          totalMinutes: 0,
          pomodoroLongBreakMinutes: null,
          sortOrder: course.sortOrder,
          hiddenFromLeaderboard: course.hiddenFromLeaderboard,
          dirty: true,
          deleted: false,
        );
        await box.put(created.id, created);
        continue;
      }

      bool changed = false;
      void update<T>(T current, T value, void Function(T) assign) {
        if (current != value) {
          assign(value);
          changed = true;
        }
      }

      update(existing.name, course.name, (v) => existing.name = v);
      update(existing.day, course.day, (v) => existing.day = v);
      update(existing.start, course.start, (v) => existing.start = v);
      update(existing.end, course.end, (v) => existing.end = v);
      update(
        existing.colorValue,
        course.colorValue,
        (v) => existing.colorValue = v,
      );
      update(existing.credits, course.credits, (v) => existing.credits = v);
      update(existing.expLevel, course.expLevel, (v) => existing.expLevel = v);
      if (course.sortOrder != null) {
        update(
          existing.sortOrder,
          course.sortOrder,
          (v) => existing.sortOrder = v,
        );
      }
      update(
        existing.hiddenFromLeaderboard,
        course.hiddenFromLeaderboard,
        (v) => existing.hiddenFromLeaderboard = v,
      );
      if (existing.deleted) {
        existing.deleted = false;
        changed = true;
      }
      if (changed) {
        existing.updatedAtMs = now;
        existing.dirty = true;
        await existing.save();
      }
    }
  }

  static int _compareCourseOrder(Course a, Course b) {
    final ao = a.sortOrder;
    final bo = b.sortOrder;
    if (ao == null && bo == null) return 0;
    if (ao == null) return 1;
    if (bo == null) return -1;
    return ao.compareTo(bo);
  }

  static Future<void> _ensureCourseOrder(List<LocalCourse> items) async {
    if (items.isEmpty) return;
    final hasAnyOrder = items.any((c) => c.sortOrder != null);
    var nextOrder = 0;
    if (hasAnyOrder) {
      final maxExisting = items
          .where((c) => c.sortOrder != null)
          .map((c) => c.sortOrder!)
          .fold<int>(0, (prev, v) => v > prev ? v : prev);
      nextOrder = maxExisting + 1;
    }
    final now = _now();
    for (final course in items) {
      if (course.sortOrder != null) continue;
      course.sortOrder = nextOrder++;
      course.updatedAtMs = now;
      course.dirty = true;
      await course.save();
    }
  }

  static Future<List<AlarmItem>> getAlarms() async {
    _ensureUser();
    final raw = _db.getMeta(_metaAlarms);
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map(
            (dynamic m) =>
                AlarmItem.fromJson(Map<String, dynamic>.from(m as Map)),
          )
          .toList();
    }
    return const [];
  }

  static Future<void> saveAlarms(List<AlarmItem> alarms) async {
    _ensureUser();
    final serialized = alarms.map((a) => a.toJson()).toList(growable: false);
    await _db.putMeta(_metaAlarms, serialized);
  }

  static Future<Map<String, int>> getCourseMinutes() async {
    _ensureUser();
    final raw = _db.getMeta(_metaCourseMinutes);
    if (raw is Map) {
      return raw.map<String, int>(
        (key, value) => MapEntry(key.toString(), (value as num).toInt()),
      );
    }
    final map = <String, int>{};
    for (final c in _db.courses()) {
      map[c.id] = c.totalMinutes;
    }
    return map;
  }

  static Future<void> saveCourseMinutes(Map<String, int> map) async {
    _ensureUser();
    await _db.putMeta(_metaCourseMinutes, map);
    final now = _now();
    for (final entry in map.entries) {
      final course = _db.getCourseById(entry.key);
      if (course == null) continue;
      if (course.totalMinutes == entry.value) continue;
      course.totalMinutes = entry.value;
      course.dirty = true;
      course.updatedAtMs = now;
      await course.save();
    }
  }

  static Future<Map<String, double>> getCourseGoalHours() async {
    _ensureUser();
    final out = <String, double>{};
    for (final goal in _db.goals()) {
      if (!goal.deleted && goal.hours != null) {
        out[goal.id] = goal.hours!;
      }
    }
    return out;
  }

  static Future<void> setCourseGoalHours(String courseId, double? hours) async {
    _ensureUser();
    final now = _now();
    final existing = _db.getGoalById(courseId);
    if (hours == null || hours <= 0) {
      if (existing != null && !existing.deleted) {
        existing.deleted = true;
        existing.dirty = true;
        existing.updatedAtMs = now;
        await existing.save();
      }
      final course = _db.getCourseById(courseId);
      if (course != null) {
        course.goalHours = null;
        await course.save();
      }
      return;
    }

    if (existing == null) {
      final goal = LocalGoal(
        id: courseId,
        uid: _db.currentUid!,
        hours: hours,
        updatedAtMs: now,
        dirty: true,
        deleted: false,
      );
      await _db.putGoal(goal);
    } else {
      existing.hours = hours;
      existing.deleted = false;
      existing.updatedAtMs = now;
      existing.dirty = true;
      await existing.save();
    }

    final course = _db.getCourseById(courseId);
    if (course != null) {
      course.goalHours = hours;
      await course.save();
    }
  }

  static Future<Map<String, int>> getPomodoroLongBreakMinutes() async {
    _ensureUser();
    final out = <String, int>{};
    for (final c in _db.courses()) {
      if (c.pomodoroLongBreakMinutes != null) {
        out[c.id] = c.pomodoroLongBreakMinutes!;
      }
    }
    return out;
  }

  static Future<void> setPomodoroLongBreakMinutes(
    String courseId,
    int minutes,
  ) async {
    _ensureUser();
    final course = _db.getCourseById(courseId);
    if (course == null) return;
    course.pomodoroLongBreakMinutes = minutes;
    await course.save();
  }

  static Future<void> removePomodoroLongBreakMinutes(String courseId) async {
    _ensureUser();
    final course = _db.getCourseById(courseId);
    if (course == null) return;
    course.pomodoroLongBreakMinutes = null;
    await course.save();
  }

  static Future<Map<String, Object?>?> getDailyState() async {
    _ensureUser();
    final raw = _db.getMeta(_metaDailyState);
    if (raw is Map) {
      final dateKey = raw['dateKey']?.toString();
      final inner = raw['map'];
      if (dateKey == null || inner is! Map) return null;
      final parsed = inner.map<String, int>(
        (key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
      );
      return {'dateKey': dateKey, 'map': parsed};
    }
    return null;
  }

  static Future<void> saveDailyState(
    String dateKey,
    Map<String, int> map,
  ) async {
    _ensureUser();
    await _db.putMeta(_metaDailyState, {'dateKey': dateKey, 'map': map});
  }

  static Map<String, dynamic>? getStreakSnapshot() {
    _ensureUser();
    final raw = _db.getMeta(_metaStreakSnapshot);
    if (raw is Map) {
      final count = (raw['count'] as num?)?.toInt();
      if (count == null) return null;
      final hasToday = raw['hasToday'] == true;
      return {'count': count, 'hasToday': hasToday};
    }
    return null;
  }

  static Future<void> saveStreakSnapshot(int count, bool hasStudyToday) async {
    _ensureUser();
    await _db.putMeta(_metaStreakSnapshot, {
      'count': count,
      'hasToday': hasStudyToday,
    });
  }

  static Future<Map<String, dynamic>?> getActiveSession() async {
    _ensureUser();
    final raw = _db.getMeta(_metaActiveSession);
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  static Future<void> saveActiveSession(Map<String, dynamic> data) async {
    _ensureUser();
    await _db.putMeta(_metaActiveSession, data);
  }

  static Future<void> clearActiveSession() async {
    _ensureUser();
    await _db.clearMetaKey(_metaActiveSession);
  }

  static Future<Map<String, dynamic>?> getTimerState() async {
    _ensureUser();
    final raw = _db.getMeta(_metaTimerState);
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  static Future<void> saveTimerState(Map<String, dynamic> data) async {
    _ensureUser();
    await _db.putMeta(_metaTimerState, data);
  }

  static Future<void> clearTimerState() async {
    _ensureUser();
    await _db.clearMetaKey(_metaTimerState);
    final doc = _userDoc();
    doc.profileName = null;
    doc.profileGoal = null;
    doc.avatarIndex = null;
    doc.avatarImage = null;
    await _saveUser(doc);
  }

  static DateTime? getLastExportMonth() {
    _ensureUser();
    final raw = LocalDatabase.instance.getMeta(_metaLastExportMonth);
    if (raw is String) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  static Future<void> setLastExportMonth(DateTime date) async {
    _ensureUser();
    final key = '${date.year}-${date.month.toString().padLeft(2, "0")}-01';
    await LocalDatabase.instance.putMeta(_metaLastExportMonth, key);
  }

  static const _metaGroupMemberStatsCache = 'group_member_stats_cache_v1';

  static Future<Map<String, dynamic>?> getGroupMemberStatsCache() async {
    _ensureUser();
    final raw = _db.getMeta(_metaGroupMemberStatsCache);
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  static Future<void> saveGroupMemberStatsCache(
    Map<String, dynamic> data,
  ) async {
    _ensureUser();
    await _db.putMeta(_metaGroupMemberStatsCache, data);
  }

  // member profile cache, name, major, goal, contact and avatar
  static const _metaMemberProfileCache = 'member_profile_cache_v1';

  static Future<Map<String, dynamic>?> getMemberProfileCache() async {
    _ensureUser();
    final raw = _db.getMeta(_metaMemberProfileCache);
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  static Future<void> saveMemberProfileCache(Map<String, dynamic> data) async {
    _ensureUser();
    await _db.putMeta(_metaMemberProfileCache, data);
  }

  static Future<void> clearMemberCacheForGroup(String groupId) async {
    _ensureUser();
    // clear member profiles for this group
    final profileCache = await getMemberProfileCache();
    if (profileCache != null) {
      profileCache.removeWhere((key, _) => key.startsWith('${groupId}_'));
      await saveMemberProfileCache(profileCache);
    }
    // clear member stats for this group
    final statsCache = await getGroupMemberStatsCache();
    if (statsCache != null) {
      statsCache.removeWhere((key, _) => key.startsWith('${groupId}_'));
      await saveGroupMemberStatsCache(statsCache);
    }
  }

  static Map<String, dynamic> _sessionToJson(LocalSession session) {
    final startUtc = DateTime.fromMillisecondsSinceEpoch(
      session.startUtcMs,
      isUtc: true,
    );
    final endUtc = DateTime.fromMillisecondsSinceEpoch(
      session.endUtcMs,
      isUtc: true,
    );
    return {
      'id': session.id,
      'courseId': session.courseId,
      'startUtc': startUtc,
      'endUtc': endUtc,
      'seconds': session.seconds,
      'kind': session.kind,
      'notes': session.notes,
    };
  }

  static Future<String?> addSession({
    required String courseId,
    required DateTime startLocal,
    required DateTime endLocal,
    String? kind,
  }) async {
    _ensureUser();
    if (!endLocal.isAfter(startLocal)) return null;
    final startUtc = startLocal.toUtc();
    final endUtc = endLocal.toUtc();
    final seconds = endUtc
        .difference(startUtc)
        .inSeconds
        .clamp(0, 1 << 31)
        .toInt();
    if (seconds <= 0) return null;

    final id = '${startUtc.microsecondsSinceEpoch}_$courseId';
    final now = _now();
    final session = LocalSession(
      id: id,
      uid: _db.currentUid!,
      courseId: courseId,
      startUtcMs: startUtc.millisecondsSinceEpoch,
      endUtcMs: endUtc.millisecondsSinceEpoch,
      seconds: seconds,
      kind: kind,
      createdAtMs: now,
      updatedAtMs: now,
      dirty: true,
      deleted: false,
    );
    await _db.putSession(session);
    _sessionUpdateController.add([
      DateTime(startLocal.year, startLocal.month, startLocal.day),
    ]);
    return id;
  }

  static Future<List<Map<String, dynamic>>> getSessions() async {
    _ensureUser();
    final sessions = _db.sessions();
    return sessions.map(_sessionToJson).toList();
  }

  static Future<bool> hasSessionOverlap(
    DateTime startLocal,
    DateTime endLocal,
  ) async {
    if (!endLocal.isAfter(startLocal)) return true;
    _ensureUser();
    final startUtc = startLocal.toUtc();
    final endUtc = endLocal.toUtc();
    for (final session in _db.sessions()) {
      final sStart = DateTime.fromMillisecondsSinceEpoch(
        session.startUtcMs,
        isUtc: true,
      );
      final sEnd = DateTime.fromMillisecondsSinceEpoch(
        session.endUtcMs,
        isUtc: true,
      );
      if (sEnd.isAfter(startUtc) && sStart.isBefore(endUtc)) {
        return true;
      }
    }
    return false;
  }

  static Future<void> clearSessions() async {
    _ensureUser();
    for (final session in _db.sessions(includeDeleted: true)) {
      session.deleted = true;
      session.dirty = true;
      session.updatedAtMs = _now();
      await session.save();
    }
  }

  static Future<List<LocalSession>> getPeerSessions(String targetUid) async {
    _ensureUser();
    return _db.peerSessions(targetUid).toList();
  }

  static Future<void> putPeerSession(LocalSession session) async {
    _ensureUser();
    // keyed by uid_sessionId to stay unique within the shared peer-sessions box
    await _db.putPeerSession(session, '${session.uid}_${session.id}');
  }

  static Future<int> getLastPeerSync(String targetUid) async {
    _ensureUser();
    final entry = _db.syncStateForKey('peer_$targetUid');
    return entry.lastPullMs;
  }

  static Future<void> setLastPeerSync(String targetUid, int timestamp) async {
    _ensureUser();
    final entry = _db.syncStateForKey('peer_$targetUid');
    entry.lastPullMs = timestamp;
    await _db.putSyncState(entry);
  }

  static Future<List<LocalCourse>> getPeerCourses(String targetUid) async {
    _ensureUser();
    return _db.peerCourses(targetUid).toList();
  }

  static Future<void> putPeerCourse(LocalCourse course) async {
    _ensureUser();
    await _db.putPeerCourse(course, '${course.uid}_${course.id}');
  }

  static Future<int> getLastPeerCourseSync(String targetUid) async {
    _ensureUser();
    final entry = _db.syncStateForKey('peer_courses_$targetUid');
    return entry.lastPullMs;
  }

  static Future<void> setLastPeerCourseSync(
    String targetUid,
    int timestamp,
  ) async {
    _ensureUser();
    final entry = _db.syncStateForKey('peer_courses_$targetUid');
    entry.lastPullMs = timestamp;
    await _db.putSyncState(entry);
  }

  static Future<Map<String, int>> secondsByCourseBetween(
    DateTime startLocal,
    DateTime endLocal,
  ) async {
    if (!endLocal.isAfter(startLocal)) return {};
    _ensureUser();
    final startUtc = startLocal.toUtc();
    final endUtc = endLocal.toUtc();
    final result = <String, int>{};
    for (final session in _db.sessions()) {
      final sStart = DateTime.fromMillisecondsSinceEpoch(
        session.startUtcMs,
        isUtc: true,
      );
      final sEnd = DateTime.fromMillisecondsSinceEpoch(
        session.endUtcMs,
        isUtc: true,
      );
      if (!sEnd.isAfter(startUtc) || !sStart.isBefore(endUtc)) continue;
      final from = sStart.isBefore(startUtc) ? startUtc : sStart;
      final to = sEnd.isAfter(endUtc) ? endUtc : sEnd;
      final secs = max(0, to.difference(from).inSeconds);
      if (secs <= 0) continue;
      result.update(
        session.courseId,
        (value) => value + secs,
        ifAbsent: () => secs,
      );
    }
    return result;
  }

  static Future<Map<DateTime, int>> getDailyTotals(
    DateTime start,
    DateTime end,
  ) async {
    _ensureUser();
    final startUtc = DateTime.utc(start.year, start.month, start.day);
    final endUtc = DateTime.utc(end.year, end.month, end.day, 23, 59, 59);

    final result = <DateTime, int>{};

    for (final session in _db.sessions()) {
      if (session.deleted) continue;

      final sStart = DateTime.fromMillisecondsSinceEpoch(
        session.startUtcMs,
        isUtc: true,
      );
      final sEnd = DateTime.fromMillisecondsSinceEpoch(
        session.endUtcMs,
        isUtc: true,
      );

      // skip sessions outside the requested range
      if (sEnd.isBefore(startUtc) || sStart.isAfter(endUtc)) continue;

      // attribute the whole session to its local start day, no splitting across days
      final sLocal = sStart.toLocal();
      final dayKey = DateTime(sLocal.year, sLocal.month, sLocal.day);

      // filter by range based on dayKey
      if (dayKey.isBefore(start) || dayKey.isAfter(end)) continue;

      final minutes = (session.seconds / 60).floor();
      if (minutes > 0) {
        result.update(dayKey, (v) => v + minutes, ifAbsent: () => minutes);
      }
    }
    return result;
  }

  static Future<List<Map<String, int>>> dailySeries(
    DateTime startLocal,
    int days,
  ) async {
    if (days <= 0) return const [];
    _ensureUser();
    final startUtc = DateTime.utc(
      startLocal.year,
      startLocal.month,
      startLocal.day,
    );
    final endUtc = startUtc.add(Duration(days: days));
    final buckets = List.generate(days, (_) => <String, int>{});

    for (final session in _db.sessions()) {
      var cursor = DateTime.fromMillisecondsSinceEpoch(
        session.startUtcMs,
        isUtc: true,
      );
      final stop = DateTime.fromMillisecondsSinceEpoch(
        session.endUtcMs,
        isUtc: true,
      );
      if (!stop.isAfter(startUtc) || !cursor.isBefore(endUtc)) continue;

      if (cursor.isBefore(startUtc)) cursor = startUtc;
      final end = stop.isAfter(endUtc) ? endUtc : stop;

      while (cursor.isBefore(end)) {
        final bucketStart = DateTime.utc(cursor.year, cursor.month, cursor.day);
        final bucketEnd = bucketStart.add(const Duration(days: 1));
        final segmentEnd = end.isBefore(bucketEnd) ? end : bucketEnd;
        final secs = segmentEnd.difference(cursor).inSeconds;
        if (secs > 0) {
          final index = bucketStart.difference(startUtc).inDays;
          if (index >= 0 && index < buckets.length) {
            buckets[index].update(
              session.courseId,
              (value) => value + secs,
              ifAbsent: () => secs,
            );
          }
        }
        cursor = bucketEnd;
      }
    }
    return buckets;
  }

  static Future<void> migrateDailyStateToSessionsIfNeeded() async {
    _ensureUser();
    final migratedFlag = _db.getMeta(_metaLegacyDailyMigrated);
    if (migratedFlag == true) return;

    final snapshot = await getDailyState();
    if (snapshot == null) {
      await _db.putMeta(_metaLegacyDailyMigrated, true);
      return;
    }

    final dateKey = snapshot['dateKey'] as String?;
    final map = snapshot['map'] as Map<String, int>?;
    if (dateKey == null || map == null) return;

    final parts = dateKey.split('-');
    if (parts.length != 3) return;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return;

    final dayStart = DateTime(year, month, day);
    final hasSessions = (await secondsByCourseBetween(
      dayStart,
      dayStart.add(const Duration(days: 1)),
    )).isNotEmpty;
    if (hasSessions) {
      await _db.putMeta(_metaLegacyDailyMigrated, true);
      return;
    }

    final anchor = DateTime(year, month, day, 12);
    for (final entry in map.entries) {
      final seconds = entry.value * 60;
      if (seconds <= 0) continue;
      await addSession(
        courseId: entry.key,
        startLocal: anchor,
        endLocal: anchor.add(Duration(seconds: seconds)),
        kind: 'legacy-migrated',
      );
    }
    await _db.putMeta(_metaLegacyDailyMigrated, true);
  }

  static Future<void> deleteSessionsForCourse(String courseId) async {
    _ensureUser();
    for (final session in _db.sessions(includeDeleted: true)) {
      if (session.courseId == courseId) {
        session.deleted = true;
        session.dirty = true;
        session.updatedAtMs = _now();
        await session.save();
      }
    }
  }

  static Future<void> removeCourseFromDailyState(String courseId) async {
    _ensureUser();
    final snapshot = await getDailyState();
    if (snapshot == null) return;
    final map = Map<String, int>.from(
      snapshot['map'] as Map<String, int>? ?? const {},
    );
    map.remove(courseId);
    await saveDailyState(snapshot['dateKey'] as String? ?? '', map);
  }

  static Future<void> removeCourseFromActiveSession(String courseId) async {
    _ensureUser();
    final current = await getActiveSession();
    if (current == null) return;
    for (final key in ['timers', 'stopwatches', 'pomodoros']) {
      final map = current[key];
      if (map is Map) {
        map.remove(courseId);
      }
    }
    await saveActiveSession(current);
  }

  static Future<void> removeCourseFromCourseMinutes(String courseId) async {
    final map = await getCourseMinutes();
    if (map.remove(courseId) != null) {
      await saveCourseMinutes(map);
    }
  }

  static Future<void> deleteSession(
    String id, {
    String? courseId,
    DateTime? startUtc,
    DateTime? endUtc,
  }) async {
    _ensureUser();

    final session = _db.getSessionById(id);
    if (session != null) {
      session.deleted = true;
      session.dirty = true;
      session.updatedAtMs = _now();
      await session.save();

      final d = DateTime.fromMillisecondsSinceEpoch(
        session.startUtcMs,
        isUtc: true,
      ).toLocal();
      _sessionUpdateController.add([DateTime(d.year, d.month, d.day)]);
      return;
    }

    final affectedDays = <DateTime>[];

    // scan all sessions as a fallback when the key lookup fails or matching by timestamp
    for (final item in _db.sessions(includeDeleted: true)) {
      bool match = false;
      if (item.id == id) {
        match = true;
      } else if (courseId != null && startUtc != null && endUtc != null) {
        final sStart = DateTime.fromMillisecondsSinceEpoch(
          item.startUtcMs,
          isUtc: true,
        );
        final sEnd = DateTime.fromMillisecondsSinceEpoch(
          item.endUtcMs,
          isUtc: true,
        );
        if (item.courseId == courseId &&
            sStart.microsecondsSinceEpoch ==
                startUtc.toUtc().microsecondsSinceEpoch &&
            sEnd.microsecondsSinceEpoch ==
                endUtc.toUtc().microsecondsSinceEpoch) {
          match = true;
        }
      }

      if (match) {
        item.deleted = true;
        item.dirty = true;
        item.updatedAtMs = _now();
        await item.save();
        // track unique days affected
        final d = DateTime.fromMillisecondsSinceEpoch(
          item.startUtcMs,
          isUtc: true,
        ).toLocal();
        final day = DateTime(d.year, d.month, d.day);
        if (!affectedDays.contains(day)) affectedDays.add(day);
      }
    }

    if (affectedDays.isNotEmpty) {
      _sessionUpdateController.add(affectedDays);
    }

    if (courseId == null || startUtc == null || endUtc == null) return;

    final firestore = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    final userId = auth.currentUser?.uid;
    if (userId != null) {
      final querySnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('sessions')
          .where('courseId', isEqualTo: courseId)
          .where('startUtc', isEqualTo: Timestamp.fromDate(startUtc))
          .where('endUtc', isEqualTo: Timestamp.fromDate(endUtc))
          .get();

      final batch = firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {
          'deleted': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final sessionDoc = firestore
          .collection('users')
          .doc(userId)
          .collection('sessions')
          .doc(id);

      final sessionSnapshot = await sessionDoc.get();
      if (sessionSnapshot.exists) {
        batch.update(sessionDoc, {
          'deleted': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    }
  }

  static Future<void> setSessionNotes(String id, String? notes) async {
    _ensureUser();
    final session = _db.getSessionById(id);
    if (session == null) return;
    final normalized = notes?.trim();
    session.notes = (normalized == null || normalized.isEmpty)
        ? null
        : normalized;
    session.dirty = true;
    session.updatedAtMs = _now();
    await session.save();
  }

  static Future<List<Map<String, dynamic>>> listSessions({
    bool newestFirst = true,
  }) async {
    final sessions = await getSessions();
    final converted = sessions.map((s) {
      final startUtc = s['startUtc'] as DateTime;
      final endUtc = s['endUtc'] as DateTime;
      return {
        ...s,
        'startLocal': startUtc.toLocal(),
        'endLocal': endUtc.toLocal(),
      };
    }).toList();

    converted.sort((a, b) {
      final da = a['startUtc'] as DateTime;
      final db = b['startUtc'] as DateTime;
      return newestFirst ? db.compareTo(da) : da.compareTo(db);
    });
    return converted;
  }

  static Future<List<HabitCategory>> getHabitCategories() async {
    _ensureUser();
    final raw = _db.getMeta(_metaHabitCategories);
    if (raw is List) {
      return raw
          .map(
            (item) =>
                HabitCategory.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    }
    return [];
  }

  static Future<void> saveHabitCategories(
    List<HabitCategory> categories,
  ) async {
    _ensureUser();
    final raw = categories.map((c) => c.toJson()).toList();
    await _db.putMeta(_metaHabitCategories, raw);
  }

  // legacy per-view habit ordering was removed in favour of a global sortorder

  // --- Habit Cache Methods ---

  static List<LocalHabit> getHabitsFromCache({bool includeDeleted = false}) {
    _ensureUser();
    return _db.habits(includeDeleted: includeDeleted).toList();
  }

  /// only active, non-archived habits from the local cache
  static List<LocalHabit> getActiveHabitsFromCache() {
    _ensureUser();
    return _db.habits().where((h) => !h.archived).toList();
  }

  /// only archived habits from the local cache
  static List<LocalHabit> getArchivedHabitsFromCache() {
    _ensureUser();
    return _db.habits().where((h) => h.archived).toList();
  }

  static LocalHabit? getHabitById(String id) {
    _ensureUser();
    return _db.getHabitById(id);
  }

  static Future<void> putHabit(LocalHabit habit) async {
    _ensureUser();
    await _db.putHabit(habit);
  }

  static List<LocalHabitHistory> getHabitHistoryFromCache(String habitId) {
    _ensureUser();
    return _db.habitHistoryForHabit(habitId).toList();
  }

  static Future<void> putHabitHistory(LocalHabitHistory entry) async {
    _ensureUser();
    await _db.putHabitHistory(entry);
  }

  /// habit history entries for one habit within a date range, local cache only
  static List<LocalHabitHistory> getHabitHistoryForDateRange(
    String habitId,
    DateTime start,
    DateTime end,
  ) {
    _ensureUser();
    final allHistory = _db.habitHistoryForHabit(habitId);
    final startKey = _dateKeyFromDateTime(start);
    final endKey = _dateKeyFromDateTime(end);

    return allHistory.where((entry) {
      final entryKey = entry.dateKey;
      return entryKey.compareTo(startKey) >= 0 &&
          entryKey.compareTo(endKey) <= 0;
    }).toList();
  }

  /// habit history entries for all habits within a date range, local cache only
  static Map<String, List<LocalHabitHistory>> getAllHabitHistoryForDateRange(
    DateTime start,
    DateTime end,
  ) {
    _ensureUser();
    final allHistory = _db.habitHistory();
    final startKey = _dateKeyFromDateTime(start);
    final endKey = _dateKeyFromDateTime(end);

    final result = <String, List<LocalHabitHistory>>{};
    for (final entry in allHistory) {
      final entryKey = entry.dateKey;
      if (entryKey.compareTo(startKey) >= 0 &&
          entryKey.compareTo(endKey) <= 0) {
        result.putIfAbsent(entry.habitId, () => []).add(entry);
      }
    }
    return result;
  }

  static String _dateKeyFromDateTime(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static Box<LocalHabit> getHabitsBox() {
    _ensureUser();
    return _db.habitsBox;
  }
}
