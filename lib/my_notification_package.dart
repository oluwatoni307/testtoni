import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  late final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  bool _initialized = false;

  // 🔧 Initialize plugin and timezones
  Future<void> initialize({Function(String?)? onNotificationTap}) async {
    if (_initialized) return;

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final initSettings = InitializationSettings(android: androidInit);

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap?.call(response.payload);
      },
    );

    // Initialize timezone database (important for schedule accuracy)
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.local);

    _initialized = true;
    print('✅ NotificationService initialized');
  }

  // ⚡ Show instant (immediate) notification
  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'instant_channel_id',
      'Instant Notifications',
      channelDescription: 'Channel for immediate notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    final details = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // ⏰ Schedule notification for specific time
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'scheduled_channel_id',
      'Scheduled Notifications',
      channelDescription: 'Channel for scheduled notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      scheduledTime.millisecondsSinceEpoch % 100000,
      title,
      body,
      tzTime,
      notificationDetails,
      androidScheduleMode:
          AndroidScheduleMode.exactAllowWhileIdle, // ✅ Required in v19.5.0+
      matchDateTimeComponents: null,
    );

    print('🕒 Scheduled → "$title" at $tzTime');
  }

  // 🚫 Cancel all scheduled notifications
  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    print('🧹 All notifications canceled');
  }
}
