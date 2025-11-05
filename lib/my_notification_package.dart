import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

/// Handles all notification setup and scheduling.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  late final FlutterLocalNotificationsPlugin _local;

  /// Initialize notifications and timezone data.
  Future<void> initialize({Function(String?)? onNotificationTap}) async {
    tzdata.initializeTimeZones();

    _local = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    final initSettings = InitializationSettings(android: androidSettings);

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap?.call(response.payload);
      },
    );

    debugPrint('✅ NotificationService initialized.');
  }

  /// Request exact alarm permission (Android 13+).
  Future<bool> ensureExactAlarmPermission() async {
    final status = await Permission.scheduleExactAlarm.status;

    if (status.isGranted) {
      debugPrint('✅ Exact alarm permission already granted.');
      return true;
    }

    final result = await Permission.scheduleExactAlarm.request();
    if (result.isGranted) {
      debugPrint('✅ Exact alarm permission granted by user.');
      return true;
    }

    debugPrint('⚠️ Exact alarm permission denied.');
    await openAppSettings();
    return false;
  }

  /// Show a notification immediately.
  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'instant_channel',
        'Instant Notifications',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Schedule a notification at a specific time.
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    final allowed = await ensureExactAlarmPermission();
    if (!allowed) {
      debugPrint(
        '⛔ Cannot schedule notification — exact alarms not permitted.',
      );
      return;
    }

    await _local.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'scheduled_channel',
          'Scheduled Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,

      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint('⏰ Scheduled "$title" at $scheduledTime');
  }

  /// Cancel all pending notifications.
  Future<void> cancelAll() async {
    await _local.cancelAll();
    debugPrint('🧹 All notifications cancelled.');
  }
}
