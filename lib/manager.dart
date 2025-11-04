// notification_manager.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

// Import your components
import 'storage.dart';
import 'model.dart';
// import 'models/notification_item.dart';
// import 'models/notification_settings.dart';

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

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  /// Initialize the notification system
  Future<void> initialize({Function(String?)? onNotificationTap}) async {
    if (_initialized) return;

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS initialization settings (if needed in future)
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize plugin
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (onNotificationTap != null) {
          onNotificationTap(details.payload);
        }
      },
    );

    // Create notification channels
    await _createNotificationChannels();

    _initialized = true;
  }

  /// Create notification channels with different priorities
  Future<void> _createNotificationChannels() async {
    // Load current settings
    final _ = await _storage.getSettings();

    // High priority channel (for critical reminders)
    const highChannel = AndroidNotificationChannel(
      'high_priority_reminders',
      'Important Reminders',
      description: 'Critical medication reminders',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // Default channel (for regular reminders)
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
  // SCHEDULING
  // ============================================================================

  /// Schedule a notification
  Future<void> schedule(NotificationItem item) async {
    // Save to database first
    await _storage.saveNotification(item);

    // Check if expired
    if (item.isExpired) {
      await delete(item.id);
      return;
    }

    // Schedule based on type
    if (item.isRecurring) {
      await _scheduleRecurring(item);
    } else {
      await _scheduleOneTime(item);
    }
  }

  /// Schedule multiple notifications
  Future<void> scheduleAll(List<NotificationItem> items) async {
    for (final item in items) {
      await schedule(item);
    }
  }

  /// Schedule a one-time notification
  Future<void> _scheduleOneTime(NotificationItem item) async {
    if (item.oneTimeDate == null) return;

    final settings = await _storage.getSettings();
    final details = await _buildNotificationDetails(settings, item);

    await _plugin.zonedSchedule(
      item.id.hashCode,
      item.title,
      item.body,
      tz.TZDateTime.from(item.oneTimeDate!, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,

      payload: item.id,
    );
  }

  /// Schedule a recurring notification
  Future<void> _scheduleRecurring(NotificationItem item) async {
    if (item.recurringTime == null) return;

    final nextTime = item.nextScheduledTime;
    if (nextTime == null) {
      // Expired, delete it
      await delete(item.id);
      return;
    }

    final settings = await _storage.getSettings();
    final details = await _buildNotificationDetails(settings, item);

    await _plugin.zonedSchedule(
      item.id.hashCode,
      item.title,
      item.body,
      tz.TZDateTime.from(nextTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,

      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      payload: item.id,
    );
  }

  // ============================================================================
  // UPDATING
  // ============================================================================

  /// Update an existing notification
  Future<void> update(String id, NotificationItem updatedItem) async {
    // Cancel old notification
    await _cancelNotification(id);

    // Update in database
    await _storage.updateNotification(updatedItem);

    // Reschedule with new details
    await schedule(updatedItem);
  }

  // ============================================================================
  // DELETING
  // ============================================================================

  /// Delete a notification
  Future<void> delete(String id) async {
    // Cancel scheduled notification
    await _cancelNotification(id);

    // Delete from database
    await _storage.deleteNotification(id);
  }

  /// Delete all notifications by source
  Future<void> deleteAllBySource(NotificationSource source) async {
    // Get all notifications from this source
    final items = await _storage.getNotificationsBySource(source);

    // Cancel each one
    for (final item in items) {
      await _cancelNotification(item.id);
    }

    // Delete from database
    await _storage.deleteAllBySource(source);
  }

  /// Delete all notifications
  Future<void> deleteAll() async {
    await _plugin.cancelAll();
    await _storage.clearAllNotifications();
  }

  /// Internal cancel method
  Future<void> _cancelNotification(String id) async {
    await _plugin.cancel(id.hashCode);
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
    // Save to storage
    await _storage.saveSettings(newSettings);

    // Recreate channels with new settings
    await _createNotificationChannels();

    // Reschedule all active notifications to apply new settings
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

    // Also cancel any that might still be scheduled
    final remaining = await getAll();
    for (final item in remaining) {
      if (item.isExpired) {
        await _cancelNotification(item.id);
      }
    }

    return count;
  }

  /// Reschedule all notifications (useful after reboot or settings change)
  Future<void> rescheduleAll() async {
    // Cancel all current
    await _plugin.cancelAll();

    // Get all from database
    final allNotifications = await getAll();

    // Reschedule each one
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
    // Determine channel based on item priority (use extras if you add priority)
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
      // Actions
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

  /// Get pending notifications (what's actually scheduled in the system)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _plugin.pendingNotificationRequests();
  }

  /// Get statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final dbStats = await _storage.getStatistics();
    final pending = await getPendingNotifications();

    return {
      ...dbStats,
      'system_pending': pending.length,
      'initialized': _initialized,
    };
  }

  /// Check health (database vs system scheduled)
  Future<Map<String, dynamic>> checkHealth() async {
    final dbNotifications = await getActive();
    final systemPending = await getPendingNotifications();

    final dbIds = dbNotifications.map((n) => n.id.hashCode).toSet();
    final systemIds = systemPending.map((p) => p.id).toSet();

    final onlyInDb = dbIds.difference(systemIds);
    final onlyInSystem = systemIds.difference(dbIds);

    return {
      'database_count': dbNotifications.length,
      'system_count': systemPending.length,
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
