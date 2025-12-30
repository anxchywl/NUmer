import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:flutter_timezone/flutter_timezone.dart';

class Notifs {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  /// Initializes the notification plugin.
  /// [isBackground] should be true if called from a background isolate.
  static Future<void> init({bool isBackground = false}) async {
    if (_inited) return;
    
    // 1. Timezone Setup
    try {
        tzdata.initializeTimeZones();
        
        String? timeZoneName;
        if (isBackground) {
            try {
                final dynamic result = await FlutterTimezone.getLocalTimezone().timeout(const Duration(seconds: 2));
                timeZoneName = result?.toString();
            } catch (e) {
                debugPrint("Notifs: Timezone detection timed out/failed in background: $e");
            }
        } else {
            final dynamic result = await FlutterTimezone.getLocalTimezone();
            timeZoneName = result?.toString();
        }

        if (timeZoneName != null) {
            tz.setLocalLocation(tz.getLocation(timeZoneName));
            debugPrint("Notifs: Timezone initialized to $timeZoneName");
        } else {
            debugPrint("Notifs: No timezone name found, using UTC");
            tz.setLocalLocation(tz.UTC);
        }
    } catch (e) {
        debugPrint("Notifs: Timezone init failed: $e, falling back to UTC");
        tz.setLocalLocation(tz.UTC);
    }

    // 2. Plugin Initialization
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false, 
      requestSoundPermission: false,
      requestBadgePermission: false,
    );
    const initSetting = InitializationSettings(android: android, iOS: ios);
    
    final success = await _plugin.initialize(
        initSetting,
        onDidReceiveNotificationResponse: (response) {
            debugPrint("Notifs: Notification tapped payload: ${response.payload}");
        },
    ); 
    debugPrint("Notifs: Plugin initialized: $success");
    
    // 3. Create Android notification channel explicitly
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
        'reminders_channel',
        'Reminders',
        description: 'Habit reminders',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ));
    }

    _inited = true;
  }

  static Future<void> requestPermissions() async {
    await init();
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidPlugin?.requestNotificationsPermission();
      debugPrint("Notifs: Android notification permission granted: $granted");
      
      final exact = await androidPlugin?.requestExactAlarmsPermission();
      debugPrint("Notifs: Android exact alarm permission granted: $exact");
    } else if (Platform.isIOS) {
       final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
       final granted = await iosPlugin?.requestPermissions(
         alert: true,
         badge: true,
         sound: true,
       );
       debugPrint("Notifs: iOS permissions granted: $granted");
    }
  }

  static Future<void> scheduleOnce({
    required int id,
    required String title,
    required String body,
    required DateTime whenLocal,
  }) async {
    await init();
    
    try {
        final tzTime = tz.TZDateTime.from(whenLocal, tz.local);
        debugPrint("Notifs: Scheduling #$id for local: $whenLocal -> tz: $tzTime");

        // Common details
        const details = NotificationDetails(
          android: AndroidNotificationDetails(
            'reminders_channel',
            'Reminders',
            channelDescription: 'Habit reminders',
            importance: Importance.max,
            priority: Priority.max,
            showWhen: true,
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.critical,
          ),
        );
        
        // Try strict exact scheduling first
        try {
          await _plugin.zonedSchedule(
            id,
            title,
            body,
            tzTime,
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: null,
          );
          debugPrint("Notifs: Scheduled exact for $id");
        } catch (e) {
          debugPrint("Notifs: Exact scheduling failed ($e), trying inexact");
          await _plugin.zonedSchedule(
            id,
            title,
            body,
            tzTime,
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: null,
          );
          debugPrint("Notifs: Scheduled inexact for $id");
        }
    } catch (e, stack) {
        debugPrint("Notifs: Fatal error scheduling $id: $e\n$stack");
    }
  }

  static Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    // Note: We don't strictly need timezone for immediate show, 
    // but init handles other plugin registration.
    await init(isBackground: true); 

    debugPrint("Notifs: Showing immediate notification $id");
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders_channel',
          'Reminders',
          importance: Importance.max,
          priority: Priority.max,
          showWhen: true,
          enableVibration: true,
          playSound: true,
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
    await init();
    final now = DateTime.now();
    var first = DateTime(
        now.year, now.month, now.day, timeLocal.hour, timeLocal.minute);
    
    // If today's time has passed, schedule for tomorrow
    if (first.isBefore(now)) {
        first = first.add(const Duration(days: 1));
    }

    final tzTime = tz.TZDateTime.from(first, tz.local);
    debugPrint("Notifs: Scheduling daily #$id starting $tzTime");

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders_channel',
          'Reminders',
          importance: Importance.max,
          priority: Priority.max,
          showWhen: true,
          enableVibration: true,
          playSound: true,
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
    debugPrint("Notifs: Cancelling $id");
    await _plugin.cancel(id);
  }

  static Future<void> cancelAll() async {
    debugPrint("Notifs: Cancelling ALL");
    await init(); 
    await _plugin.cancelAll();
  }
}
