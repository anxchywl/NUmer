import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:flutter_timezone/flutter_timezone.dart';

// wraps flutter_local_notifications for reminders, alarms and session notifications
class Notifs {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _inited = false;
  static const _channelId = 'reminders_channel';
  static const _channelName = 'Notifications';
  static const _channelDescription = 'Timers, alarms, and nudges.';

  /// initializes the notification plugin
  /// isBackground is true when called from a background isolate
  static Future<void> init({bool isBackground = false}) async {
    if (_inited) return;

    // 1. timezone setup
    try {
      tzdata.initializeTimeZones();

      String? timeZoneName;
      if (isBackground) {
        try {
          final dynamic result = await FlutterTimezone.getLocalTimezone()
              .timeout(const Duration(seconds: 2));
          timeZoneName = result?.toString();
        } catch (e) {
          debugPrint(
              "Notifs: Timezone detection timed out/failed in background: $e");
        }
      } else {
        try {
          final dynamic result = await FlutterTimezone.getLocalTimezone();
          timeZoneName = result?.toString();
        } catch (e) {
          debugPrint("Notifs: Timezone detection failed: $e");
        }
      }

      if (timeZoneName != null) {
        try {
          tz.setLocalLocation(tz.getLocation(timeZoneName));
          debugPrint("Notifs: Timezone initialized to $timeZoneName");
        } catch (e) {
          debugPrint(
              "Notifs: Invalid timezone '$timeZoneName', falling back to UTC. Error: $e");
          tz.setLocalLocation(tz.UTC);
        }
      } else {
        debugPrint("Notifs: No timezone name found, using UTC");
        tz.setLocalLocation(tz.UTC);
      }
    } catch (e) {
      debugPrint("Notifs: Timezone init failed: $e, falling back to UTC");
      try {
        tz.setLocalLocation(tz.UTC);
      } catch (_) {}
    }

    // 2. plugin initialization
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestSoundPermission: false,
      requestBadgePermission: false,
    );
    const initSetting = InitializationSettings(android: android, iOS: ios);

    final success = await _plugin.initialize(
      settings: initSetting,
      onDidReceiveNotificationResponse: (response) {
        debugPrint("Notifs: Notification tapped payload: ${response.payload}");
      },
    );
    debugPrint("Notifs: Plugin initialized: $success");

    // 3. create the android notification channel explicitly
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin
          ?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ));
    }

    _inited = true;
  }

  static Future<void> scheduleOnce({
    required int id,
    required String title,
    required String body,
    required DateTime whenLocal,
  }) async {
    // ensure the id is a valid 32-bit int
    id = id & 0x7FFFFFFF;
    await init();

    try {
      final tzTime = tz.TZDateTime.from(whenLocal, tz.local);
      debugPrint(
          "Notifs: Scheduling #$id for local: $whenLocal -> tz: $tzTime");

      // common details
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.max,
          showWhen: true,
          enableVibration: true,
          playSound: true,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.critical,
        ),
      );

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: null,
      );
      debugPrint("Notifs: Scheduled inexact for $id");
    } catch (e, stack) {
      debugPrint("Notifs: Fatal error scheduling $id: $e\n$stack");
    }
  }

  static Future<void> showImmediate({
    required int id,
    required String title,
    required String body,
  }) async {
    // background-safe init
    await init(isBackground: true);

    debugPrint("Notifs: Showing immediate notification $id");
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.max,
          priority: Priority.max,
          showWhen: true,
          enableVibration: true,
          playSound: true,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  static Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required DateTime timeLocal,
  }) async {
    // ensure the id is a valid 32-bit int
    id = id & 0x7FFFFFFF;
    await init();
    final now = DateTime.now();
    var first = DateTime(
        now.year, now.month, now.day, timeLocal.hour, timeLocal.minute);

    // if the time has already passed today, schedule for tomorrow
    if (first.isBefore(now)) {
      first = first.add(const Duration(days: 1));
    }

    final tzTime = tz.TZDateTime.from(first, tz.local);
    debugPrint("Notifs: Scheduling daily #$id starting $tzTime");

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzTime,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.max,
          priority: Priority.max,
          showWhen: true,
          enableVibration: true,
          playSound: true,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancel(int id) async {
    // ensure the id matches the schedule logic, 32-bit positive int
    id = id & 0x7FFFFFFF;
    debugPrint("Notifs: Cancelling $id");
    await _plugin.cancel(id: id);
  }

  static Future<void> cancelAll() async {
    debugPrint("Notifs: Cancelling ALL");
    await init();
    await _plugin.cancelAll();
  }
}
