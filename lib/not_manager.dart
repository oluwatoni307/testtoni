// notification_manager.dart
// Complete implementation with native backend support

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

// Import your components
import 'storage.dart';
import 'model.dart';
import 'native_alarm_manager.dart';

// Scheduling backend options
enum SchedulingBackend {
  native, // Use native Android AlarmManager (most reliable)
  flutter, // Use flutter_local_notifications (fallback)
  hybrid, // Try native first, fallback to flutter
}

class NotificationManager {
  static NotificationManager? _instance;

  // Singleton pattern
  NotificationManager._();

  factory NotificationManager() {
    _instance ??= NotificationManager._();
    return _instance!;
  }

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final NotificationStorage _storage = NotificationStorage();

  bool _initialized = false;
  Function(String?)? _onNotificationTap;

  // Backend selection
  SchedulingBackend _backend = SchedulingBackend.native;

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  /// Initialize the notification system
  Future<void> initialize({Function(String?)? onNotificationTap}) async {
    if (_initialized) return;

    debugPrint('');
    debugPrint('╔═══════════════════════════════════════════════════════════╗');
    debugPrint('║ INITIALIZING NOTIFICATION MANAGER (WITH NATIVE BACKEND)  ║');
    debugPrint('╚═══════════════════════════════════════════════════════════╝');

    _onNotificationTap = onNotificationTap;

    // Check native backend availability
    final canUseNative = await NativeAlarmManager.canScheduleExactAlarms();
    if (!canUseNative) {
      debugPrint('⚠️ Native backend not available, using Flutter backend');
      _backend = SchedulingBackend.flutter;
    } else {
      debugPrint('✅ Native backend available');
    }

    // Ensure timezone data is initialized before using tz.local
    debugPrint('🌍 Initializing timezone...');
    try {
      tzdata.initializeTimeZones();
      debugPrint('✅ Timezone data initialized');

      try {
        tz.setLocalLocation(tz.getLocation('Africa/Lagos'));
        debugPrint('✅ Timezone set to: ${tz.local.name}');
        debugPrint('   Current time: ${tz.TZDateTime.now(tz.local)}');
      } catch (e) {
        debugPrint('⚠️ Failed to set Africa/Lagos: $e');
        try {
          tz.setLocalLocation(tz.getLocation('UTC'));
          debugPrint('⚠️ Using UTC as fallback');
        } catch (e2) {
          debugPrint('❌ Failed to set fallback timezone: $e2');
        }
      }
    } catch (e) {
      debugPrint('❌ Timezone initialization failed: $e');
    }

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettings = InitializationSettings(android: androidSettings);

    debugPrint('');
    debugPrint('📱 Initializing notification plugin...');

    // Initialize plugin
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('📬 Notification tapped: ${details.payload}');
        if (_onNotificationTap != null) {
          _onNotificationTap!(details.payload);
        }
      },
    );

    debugPrint('✅ Plugin initialized');

    // Create notification channels
    debugPrint('');
    debugPrint('📢 Creating notification channels...');
    await _createNotificationChannels();
    debugPrint('✅ Channels created');

    _initialized = true;

    debugPrint('');
    debugPrint('✅ NOTIFICATION MANAGER READY');
    debugPrint('   Backend: ${_backend.name}');
    debugPrint('╚═══════════════════════════════════════════════════════════╝');
    debugPrint('');
  }

  /// Update the notification tap callback without re-initializing
  void updateTapCallback(Function(String?)? onNotificationTap) {
    _onNotificationTap = onNotificationTap;
  }

  /// Create notification channels with different priorities
  Future<void> _createNotificationChannels() async {
    final _ = await _storage.getSettings();

    // High priority channel
    const highChannel = AndroidNotificationChannel(
      'high_priority_reminders',
      'Important Reminders',
      description: 'Critical medication reminders',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // Default channel
    const defaultChannel = AndroidNotificationChannel(
      'default_reminders',
      'Reminders',
      description: 'Regular medication reminders',
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: true,
    );

    // Create channels
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(highChannel);

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(defaultChannel);
  }

  // ============================================================================
  // BACKEND MANAGEMENT
  // ============================================================================

  /// Switch scheduling backend
  void setBackend(SchedulingBackend backend) {
    _backend = backend;
    debugPrint('🔄 Scheduling backend changed to: ${backend.name}');
  }

  /// Get current backend
  SchedulingBackend getBackend() => _backend;

  /// Check native alarm health
  Future<NativeAlarmHealth> checkNativeHealth() async {
    return await NativeAlarmManager.checkHealth();
  }

  /// Get native scheduled alarms
  Future<List<NativeAlarmInfo>> getNativeScheduledAlarms() async {
    return await NativeAlarmManager.getAllScheduledAlarms();
  }

  /// Check if can schedule exact alarms
  Future<bool> canScheduleExactAlarms() async {
    return await NativeAlarmManager.canScheduleExactAlarms();
  }

  /// Open alarm settings
  Future<bool> openAlarmSettings() async {
    return await NativeAlarmManager.openAlarmSettings();
  }

  // ============================================================================
  // SCHEDULING
  // ============================================================================

  /// Schedule a notification
  Future<void> schedule(NotificationItem item) async {
    if (!_initialized) {
      debugPrint('NotificationManager not initialized — initializing now');
      await initialize();
    }

    int notificationId = item.id.hashCode.abs(); // Always positive

    debugPrint('');
    debugPrint('┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓');
    debugPrint('┃ SCHEDULING NOTIFICATION                         ┃');
    debugPrint('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛');
    debugPrint('String ID: ${item.id}');
    debugPrint('Int ID (abs): $notificationId');
    debugPrint('Title: ${item.title}');
    debugPrint('Body: ${item.body}');
    debugPrint('Backend: ${_backend.name}');
    debugPrint('Type: ${item.isRecurring ? "Recurring" : "One-time"}');

    if (item.isRecurring) {
      debugPrint('Recurring time: ${item.recurringTime}');
      debugPrint('Next scheduled: ${item.nextScheduledTime}');
    } else {
      debugPrint('One-time date: ${item.oneTimeDate}');
    }

    // Save to database first
    debugPrint('');
    debugPrint('💾 Saving to database...');
    try {
      await _storage.saveNotification(item);
      debugPrint('✅ Saved to database successfully');
    } catch (e) {
      debugPrint('❌ Failed to save to database: $e');
      rethrow;
    }

    // Check if expired
    if (item.isExpired) {
      debugPrint('⚠️ Notification is expired, deleting...');
      await delete(item.id);
      debugPrint('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛');
      return;
    }

    // Schedule based on type
    debugPrint('');
    debugPrint('📅 Scheduling in system...');
    if (item.isRecurring) {
      await _scheduleRecurring(item);
    } else {
      await _scheduleOneTime(item);
    }

    debugPrint('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛');
    debugPrint('');
  }

  /// Schedule multiple notifications
  Future<void> scheduleAll(List<NotificationItem> items) async {
    for (final item in items) {
      await schedule(item);
    }
  }

  /// Schedule a one-time notification (routes to backend)
  Future<void> _scheduleOneTime(NotificationItem item) async {
    debugPrint('  → _scheduleOneTime() called with backend: ${_backend.name}');

    if (item.oneTimeDate == null) {
      debugPrint('  ❌ oneTimeDate is null, cannot schedule');
      return;
    }

    switch (_backend) {
      case SchedulingBackend.native:
        await _scheduleOneTimeNative(item);
        break;
      case SchedulingBackend.flutter:
        await _scheduleOneTimeFlutter(item);
        break;
      case SchedulingBackend.hybrid:
        final success = await _scheduleOneTimeNative(item);
        if (!success) {
          debugPrint('  ⚠️ Native scheduling failed, falling back to flutter');
          await _scheduleOneTimeFlutter(item);
        }
        break;
    }
  }

  /// Schedule one-time via native backend
  Future<bool> _scheduleOneTimeNative(NotificationItem item) async {
    debugPrint('  → Using NATIVE backend');

    if (item.oneTimeDate == null) return false;

    try {
      final now = DateTime.now();
      var scheduledTime = item.oneTimeDate!;

      // Adjust if time is in past or too close
      if (scheduledTime.difference(now).inSeconds < 10) {
        debugPrint('  ⚡ Time too close or in past, adjusting...');
        scheduledTime = now.add(const Duration(seconds: 30));
        debugPrint('  ✅ Adjusted to: $scheduledTime (30s from now)');
      }

      final notificationId = item.id.hashCode.abs();

      final success = await NativeAlarmManager.scheduleAlarm(
        id: notificationId,
        title: item.title,
        body: item.body,
        scheduledTime: scheduledTime,
        payload: item.id,
      );

      if (success) {
        debugPrint('  ✅ Successfully scheduled via native backend');
      } else {
        debugPrint('  ❌ Native scheduling returned false');
      }

      return success;
    } catch (e, st) {
      debugPrint('  ❌ EXCEPTION in _scheduleOneTimeNative:');
      debugPrint('     Error: $e');
      debugPrint('     Stack trace: $st');
      return false;
    }
  }

  /// Schedule one-time via flutter backend
  Future<void> _scheduleOneTimeFlutter(NotificationItem item) async {
    debugPrint('  → Using FLUTTER backend');

    if (item.oneTimeDate == null) {
      debugPrint('  ❌ oneTimeDate is null, cannot schedule');
      return;
    }

    final settings = await _storage.getSettings();
    final details = await _buildNotificationDetails(settings, item);

    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime.from(item.oneTimeDate!, tz.local);

      debugPrint('  📍 Timezone info:');
      debugPrint('     Now (TZ): $now');
      debugPrint('     Scheduled (TZ): $scheduled');
      debugPrint('     Difference: ${scheduled.difference(now)}');

      // Adjust if in past or too close
      if (scheduled.difference(now).inSeconds < 10) {
        debugPrint('  ⚡ Time too close or in past, adjusting...');
        scheduled = now.add(const Duration(seconds: 30));
        debugPrint('  ✅ Adjusted to: $scheduled');
      }

      final notificationId = item.id.hashCode.abs();

      debugPrint('  ✅ Time is valid, calling zonedSchedule...');

      await _plugin.zonedSchedule(
        notificationId,
        item.title,
        item.body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,

        payload: item.id,
      );

      debugPrint('  ✅ zonedSchedule completed without error');
    } catch (e, st) {
      debugPrint('  ❌ EXCEPTION in _scheduleOneTimeFlutter:');
      debugPrint('     Error: $e');
      debugPrint('     Stack trace: $st');
    }
  }

  /// Schedule a recurring notification (routes to backend)
  Future<void> _scheduleRecurring(NotificationItem item) async {
    if (item.recurringTime == null) return;

    final nextTime = item.nextScheduledTime;
    if (nextTime == null) {
      await delete(item.id);
      return;
    }

    switch (_backend) {
      case SchedulingBackend.native:
        await _scheduleRecurringNative(item, nextTime);
        break;
      case SchedulingBackend.flutter:
        await _scheduleRecurringFlutter(item, nextTime);
        break;
      case SchedulingBackend.hybrid:
        final success = await _scheduleRecurringNative(item, nextTime);
        if (!success) {
          await _scheduleRecurringFlutter(item, nextTime);
        }
        break;
    }
  }

  /// Schedule recurring via native backend
  Future<bool> _scheduleRecurringNative(
    NotificationItem item,
    DateTime nextTime,
  ) async {
    try {
      var scheduled = nextTime;
      final now = DateTime.now();

      // Move forward if in past
      int safety = 0;
      while (!scheduled.isAfter(now) && safety < 7) {
        scheduled = scheduled.add(const Duration(days: 1));
        safety++;
      }

      if (!scheduled.isAfter(now)) {
        debugPrint('⚠️ Could not compute future time for ${item.id}');
        return false;
      }

      final notificationId = item.id.hashCode.abs();

      debugPrint('📅 Scheduling recurring via native: ${item.id}');
      debugPrint('   ID: $notificationId');
      debugPrint('   Time: $scheduled');

      final success = await NativeAlarmManager.scheduleAlarm(
        id: notificationId,
        title: item.title,
        body: item.body,
        scheduledTime: scheduled,
        payload: item.id,
      );

      if (success) {
        debugPrint('   ✅ Recurring alarm scheduled via native');
      }

      return success;
    } catch (e, st) {
      debugPrint('❌ Failed recurring native: ${item.id}: $e\n$st');
      return false;
    }
  }

  /// Schedule recurring via flutter backend
  Future<void> _scheduleRecurringFlutter(
    NotificationItem item,
    DateTime nextTime,
  ) async {
    final settings = await _storage.getSettings();
    final details = await _buildNotificationDetails(settings, item);

    try {
      var scheduled = tz.TZDateTime.from(nextTime, tz.local);
      final now = tz.TZDateTime.now(tz.local);

      // Move forward if in past
      int safety = 0;
      while (!scheduled.isAfter(now) && safety < 7) {
        scheduled = scheduled.add(const Duration(days: 1));
        safety++;
      }

      if (!scheduled.isAfter(now)) {
        debugPrint('⚠️ Could not compute future time for ${item.id}');
        return;
      }

      final notificationId = item.id.hashCode.abs();

      debugPrint('📅 Scheduling recurring via flutter: ${item.id}');

      await _plugin.zonedSchedule(
        notificationId,
        item.title,
        item.body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,

        payload: item.id,
      );

      debugPrint('   ✅ Recurring alarm scheduled via flutter');
    } catch (e, st) {
      debugPrint('❌ Failed recurring flutter: ${item.id}: $e\n$st');
    }
  }

  // ============================================================================
  // IMMEDIATE NOTIFICATIONS
  // ============================================================================

  /// Show a notification immediately (not scheduled)
  Future<void> showNow(NotificationItem item) async {
    if (!_initialized) {
      debugPrint('NotificationManager not initialized — initializing now');
      await initialize();
    }

    int notificationId = item.id.hashCode.abs();

    debugPrint('');
    debugPrint('┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓');
    debugPrint('┃ SHOWING IMMEDIATE NOTIFICATION                  ┃');
    debugPrint('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛');
    debugPrint('ID: $notificationId');
    debugPrint('Title: ${item.title}');
    debugPrint('Body: ${item.body}');

    final settings = await _storage.getSettings();
    final details = await _buildNotificationDetails(settings, item);

    try {
      await _plugin.show(
        notificationId,
        item.title,
        item.body,
        details,
        payload: item.id,
      );

      debugPrint('✅ Notification shown immediately');
    } catch (e, st) {
      debugPrint('❌ EXCEPTION showing immediate notification:');
      debugPrint('   Error: $e');
      debugPrint('   Stack trace: $st');
      rethrow;
    }

    debugPrint('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛');
    debugPrint('');
  }

  /// Show multiple notifications immediately
  Future<void> showNowMultiple(List<NotificationItem> items) async {
    for (final item in items) {
      await showNow(item);
    }
  }

  // ============================================================================
  // UPDATING
  // ============================================================================

  /// Update an existing notification
  Future<void> update(String id, NotificationItem updatedItem) async {
    await _cancelNotification(id);
    await _storage.updateNotification(updatedItem);
    await schedule(updatedItem);
  }

  // ============================================================================
  // DELETING
  // ============================================================================

  /// Delete a notification
  Future<void> delete(String id) async {
    await _cancelNotification(id);
    await _storage.deleteNotification(id);
  }

  /// Delete all notifications by source
  Future<void> deleteAllBySource(NotificationSource source) async {
    final items = await _storage.getNotificationsBySource(source);

    for (final item in items) {
      await _cancelNotification(item.id);
    }

    await _storage.deleteAllBySource(source);
  }

  /// Delete all notifications
  Future<void> deleteAll() async {
    // Cancel from both backends
    await _plugin.cancelAll();
    await NativeAlarmManager.cancelAllAlarms();
    await _storage.clearAllNotifications();
  }

  /// Internal cancel method
  Future<void> _cancelNotification(String id) async {
    final notificationId = id.hashCode.abs();

    // Cancel from native backend
    if (_backend == SchedulingBackend.native ||
        _backend == SchedulingBackend.hybrid) {
      await NativeAlarmManager.cancelAlarm(notificationId);
    }

    // Also cancel from flutter plugin
    await _plugin.cancel(notificationId);
  }

  // ============================================================================
  // QUERYING
  // ============================================================================

  /// Get all scheduled notifications
  Future<List<NotificationItem>> getAll() async {
    return await _storage.getAllNotifications();
  }

  /// Get notifications by source
  Future<List<NotificationItem>> getBySource(NotificationSource source) async {
    return await _storage.getNotificationsBySource(source);
  }

  /// Get active notifications only
  Future<List<NotificationItem>> getActive() async {
    return await _storage.getActiveNotifications();
  }

  /// Get notification by ID
  Future<NotificationItem?> getById(String id) async {
    return await _storage.getNotificationById(id);
  }

  // ============================================================================
  // SETTINGS
  // ============================================================================

  /// Update notification settings
  Future<void> updateSettings(NotificationSettings newSettings) async {
    await _storage.saveSettings(newSettings);
    await _createNotificationChannels();

    final activeNotifications = await getActive();
    for (final item in activeNotifications) {
      await _cancelNotification(item.id);
      if (item.isRecurring) {
        await _scheduleRecurring(item);
      } else {
        await _scheduleOneTime(item);
      }
    }
  }

  /// Get current settings
  Future<NotificationSettings> getSettings() async {
    return await _storage.getSettings();
  }

  // ============================================================================
  // MAINTENANCE
  // ============================================================================

  /// Clean up expired notifications
  Future<int> cleanupExpired() async {
    final count = await _storage.deleteExpiredNotifications();

    final remaining = await getAll();
    for (final item in remaining) {
      if (item.isExpired) {
        await _cancelNotification(item.id);
      }
    }

    return count;
  }

  /// Reschedule all notifications
  Future<void> rescheduleAll() async {
    await _plugin.cancelAll();
    await NativeAlarmManager.cancelAllAlarms();

    final allNotifications = await getAll();

    for (final item in allNotifications) {
      if (item.isExpired) {
        await delete(item.id);
      } else if (item.isActive) {
        if (item.isRecurring) {
          await _scheduleRecurring(item);
        } else {
          await _scheduleOneTime(item);
        }
      }
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Build notification details with current settings
  Future<NotificationDetails> _buildNotificationDetails(
    NotificationSettings settings,
    NotificationItem item,
  ) async {
    final channelId = item.extras?['priority'] == 'high'
        ? 'high_priority_reminders'
        : 'default_reminders';

    final channelName = item.extras?['priority'] == 'high'
        ? 'Important Reminders'
        : 'Reminders';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Medication reminders',
      importance: _getImportance(settings.priority),
      priority: _getPriority(settings.priority),
      playSound: settings.sound,
      enableVibration: settings.vibration,
      styleInformation: BigTextStyleInformation(item.body),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'mark_taken',
          'Mark as Taken',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction('snooze', 'Snooze 10 min'),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  /// Convert priority enum to Android Importance
  Importance _getImportance(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Importance.low;
      case NotificationPriority.medium:
        return Importance.defaultImportance;
      case NotificationPriority.high:
        return Importance.high;
      case NotificationPriority.urgent:
        return Importance.max;
    }
  }

  /// Convert priority enum to Android Priority
  Priority _getPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Priority.low;
      case NotificationPriority.medium:
        return Priority.defaultPriority;
      case NotificationPriority.high:
        return Priority.high;
      case NotificationPriority.urgent:
        return Priority.max;
    }
  }

  // ============================================================================
  // DIAGNOSTICS
  // ============================================================================

  /// Get pending notifications (from flutter plugin)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    // If using native backend, return native scheduled alarms mapped to
    // PendingNotificationRequest so callers (tests/diagnostics) can
    // compare `id`, `title`, and `body` uniformly.
    if (_backend == SchedulingBackend.native) {
      try {
        final nativeAlarms = await NativeAlarmManager.getAllScheduledAlarms();
        return nativeAlarms
            .map(
              (a) =>
                  PendingNotificationRequest(a.id, a.title, a.body, a.payload),
            )
            .toList();
      } catch (e) {
        debugPrint('❌ Failed to fetch native alarms: $e');
        return <PendingNotificationRequest>[];
      }
    }

    // Hybrid backend: merge both sets (native + flutter) and dedupe by id
    if (_backend == SchedulingBackend.hybrid) {
      final flutterPending = await _plugin.pendingNotificationRequests();
      final nativeAlarms = await NativeAlarmManager.getAllScheduledAlarms();

      final mappedNative = nativeAlarms
          .map(
            (a) => PendingNotificationRequest(a.id, a.title, a.body, a.payload),
          )
          .toList();

      // Merge and dedupe by id
      final Map<int, PendingNotificationRequest> byId = {};
      for (final p in flutterPending) {
        byId[p.id] = p;
      }
      for (final p in mappedNative) {
        byId[p.id] = p;
      }

      return byId.values.toList();
    }

    // Default: flutter backend
    return await _plugin.pendingNotificationRequests();
  }

  /// Get statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final dbStats = await _storage.getStatistics();
    final flutterPending = await getPendingNotifications();
    final nativeAlarms = await NativeAlarmManager.getAllScheduledAlarms();

    return {
      ...dbStats,
      'flutter_pending': flutterPending.length,
      'native_pending': nativeAlarms.length,
      'backend': _backend.name,
      'initialized': _initialized,
    };
  }

  /// Check health (database vs system scheduled)
  Future<Map<String, dynamic>> checkHealth() async {
    final dbNotifications = await getActive();
    final flutterPending = await getPendingNotifications();
    final nativeAlarms = await NativeAlarmManager.getAllScheduledAlarms();

    final dbIds = dbNotifications.map((n) => n.id.hashCode.abs()).toSet();

    Set<int> systemIds;
    if (_backend == SchedulingBackend.native) {
      systemIds = nativeAlarms.map((a) => a.id).toSet();
    } else {
      systemIds = flutterPending.map((p) => p.id).toSet();
    }

    final onlyInDb = dbIds.difference(systemIds);
    final onlyInSystem = systemIds.difference(dbIds);

    return {
      'database_count': dbNotifications.length,
      'flutter_system_count': flutterPending.length,
      'native_system_count': nativeAlarms.length,
      'active_backend': _backend.name,
      'in_sync': onlyInDb.isEmpty && onlyInSystem.isEmpty,
      'missing_in_system': onlyInDb.length,
      'missing_in_db': onlyInSystem.length,
    };
  }

  /// Print diagnostics
  Future<void> printDiagnostics() async {
    debugPrint('=== Notification Manager Diagnostics ===');

    final stats = await getStatistics();
    debugPrint('Statistics:');
    stats.forEach((key, value) => debugPrint('  $key: $value'));

    final health = await checkHealth();
    debugPrint('\nHealth Check:');
    health.forEach((key, value) => debugPrint('  $key: $value'));

    debugPrint('=======================================');
  }
}
