// notification_manager.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

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
  Function(String?)? _onNotificationTap;

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  /// Initialize the notification system
  Future<void> initialize({Function(String?)? onNotificationTap}) async {
    if (_initialized) return;

    debugPrint('');
    debugPrint('╔═══════════════════════════════════════════════════════════╗');
    debugPrint('║ INITIALIZING NOTIFICATION MANAGER                         ║');
    debugPrint('╚═══════════════════════════════════════════════════════════╝');

    _onNotificationTap = onNotificationTap;

    // Ensure timezone data is initialized before using tz.local
    debugPrint('🌍 Initializing timezone...');
    try {
      tzdata.initializeTimeZones();
      debugPrint('✅ Timezone data initialized');

      // Hardcode Lagos timezone since you're in Nigeria
      try {
        tz.setLocalLocation(tz.getLocation('Africa/Lagos'));
        debugPrint('✅ Timezone set to: ${tz.local.name}');
        debugPrint('   Current time: ${tz.TZDateTime.now(tz.local)}');
      } catch (e) {
        debugPrint('⚠️ Failed to set Africa/Lagos: $e');
        try {
          tz.setLocalLocation(tz.getLocation('UTC'));
          debugPrint('⚠️ Using UTC as fallback');
          debugPrint('   Current time: ${tz.TZDateTime.now(tz.local)}');
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
    debugPrint('╚═══════════════════════════════════════════════════════════╝');
    debugPrint('');
  }

  /// Update the notification tap callback without re-initializing
  void updateTapCallback(Function(String?)? onNotificationTap) {
    _onNotificationTap = onNotificationTap;
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
  /// Schedule a notification
  Future<void> schedule(NotificationItem item) async {
    // Ensure manager is initialized (safety for callers that didn't await)
    if (!_initialized) {
      debugPrint('NotificationManager not initialized — initializing now');
      await initialize();
    }

    // 🔍 DEBUG: Start of scheduling
    int notificationId = item.id.hashCode;
    debugPrint('');
    debugPrint('┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓');
    debugPrint('┃ SCHEDULING NOTIFICATION                         ┃');
    debugPrint('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛');
    debugPrint('String ID: ${item.id}');
    debugPrint('Int ID (hashCode): $notificationId');
    debugPrint('HashCode is negative: ${notificationId < 0}');
    debugPrint('Title: ${item.title}');
    debugPrint('Body: ${item.body}');
    debugPrint('Source: ${item.source.name}');
    debugPrint('Type: ${item.isRecurring ? "Recurring" : "One-time"}');
    debugPrint('Is expired: ${item.isExpired}');
    debugPrint('Is active: ${item.isActive}');

    if (item.isRecurring) {
      debugPrint('Recurring time: ${item.recurringTime}');
      debugPrint('Next scheduled: ${item.nextScheduledTime}');
      debugPrint('End date: ${item.endDate}');
    } else {
      debugPrint('One-time date: ${item.oneTimeDate}');
      if (item.oneTimeDate != null) {
        final now = DateTime.now();
        debugPrint('Current time: $now');
        debugPrint('Time difference: ${item.oneTimeDate!.difference(now)}');
        debugPrint('Is in future: ${item.oneTimeDate!.isAfter(now)}');
      }
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
      debugPrint('');
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

    // 🔍 DEBUG: Verify it was actually scheduled
    debugPrint('');
    debugPrint('🔍 Verifying in system...');
    final pending = await _plugin.pendingNotificationRequests();
    bool found = pending.any((p) => p.id == notificationId);

    if (found) {
      debugPrint('✅ VERIFIED in system pending notifications');
      final matchingNotif = pending.firstWhere((p) => p.id == notificationId);
      debugPrint('   ID: ${matchingNotif.id}');
      debugPrint('   Title: ${matchingNotif.title}');
      debugPrint('   Body: ${matchingNotif.body}');
    } else {
      debugPrint('❌ NOT FOUND in system pending notifications!');
      debugPrint('   System has ${pending.length} pending notifications:');
      for (var p in pending.take(5)) {
        debugPrint('   - ID: ${p.id}, Title: ${p.title}');
      }
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

  /// Schedule a one-time notification
  Future<void> _scheduleOneTime(NotificationItem item) async {
    debugPrint('  → _scheduleOneTime() called');

    if (item.oneTimeDate == null) {
      debugPrint('  ❌ oneTimeDate is null, cannot schedule');
      return;
    }

    final settings = await _storage.getSettings();
    final details = await _buildNotificationDetails(settings, item);

    try {
      final now = tz.TZDateTime.now(tz.local);
      final scheduled = tz.TZDateTime.from(item.oneTimeDate!, tz.local);

      debugPrint('  📍 Timezone info:');
      debugPrint('     tz.local: ${tz.local.name}');
      debugPrint('     Now (TZ): $now');
      debugPrint('     Scheduled (TZ): $scheduled');
      debugPrint('     Difference: ${scheduled.difference(now)}');
      debugPrint('     Is after now: ${scheduled.isAfter(now)}');

      if (!scheduled.isAfter(now)) {
        debugPrint('  ⚠️ SKIPPING: Scheduled time is NOT in the future');
        debugPrint('     This is why the notification was not scheduled!');
        return;
      }

      debugPrint('  ✅ Time is valid, calling zonedSchedule...');

      await _plugin.zonedSchedule(
        item.id.hashCode,
        item.title,
        item.body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: item.id,
      );

      debugPrint('  ✅ zonedSchedule completed without error');

      final pending = await _plugin.pendingNotificationRequests();
      debugPrint('  📊 Pending count after schedule: ${pending.length}');
    } catch (e, st) {
      debugPrint('  ❌ EXCEPTION in _scheduleOneTime:');
      debugPrint('     Error: $e');
      debugPrint('     Stack trace: $st');
    }
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
    try {
      // Convert nextTime (DateTime) into TZDateTime in local zone and ensure it's in the future
      var scheduled = tz.TZDateTime.from(nextTime, tz.local);
      final now = tz.TZDateTime.now(tz.local);

      // If scheduled is not in the future, move it forward by one day until it is.
      int safety = 0;
      while (!scheduled.isAfter(now) && safety < 7) {
        scheduled = scheduled.add(const Duration(days: 1));
        safety++;
      }

      if (!scheduled.isAfter(now)) {
        debugPrint(
          'Skipping recurring scheduling for ${item.id}: could not compute future instance (nextTime: $nextTime)',
        );
        return;
      }

      debugPrint(
        'Scheduling recurring notification ${item.id} at $scheduled (now: $now)',
      );

      await _plugin.zonedSchedule(
        item.id.hashCode,
        item.title,
        item.body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
        payload: item.id,
      );

      final pending = await _plugin.pendingNotificationRequests();
      debugPrint(
        'Pending notifications after scheduling recurring (${item.id}): ${pending.map((p) => p.id).toList()}',
      );
    } catch (e, st) {
      debugPrint(
        'Failed to schedule recurring notification ${item.id}: $e\n$st',
      );
    }
  }

  // ============================================================================
  // IMMEDIATE NOTIFICATIONS
  // ============================================================================

  /// Show a notification immediately (not scheduled)
  Future<void> showNow(NotificationItem item) async {
    // Ensure manager is initialized
    if (!_initialized) {
      debugPrint('NotificationManager not initialized — initializing now');
      await initialize();
    }

    int notificationId = item.id.hashCode.abs(); // Use positive ID

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
