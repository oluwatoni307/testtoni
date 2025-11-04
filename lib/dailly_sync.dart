// daily_sync.dart

import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

// Import your components
import 'manager.dart';
import 'storage.dart';
import 'model.dart';
// import 'models/sync_result.dart';

/// Base class for daily sync strategies
abstract class DailySync {
  /// Perform the daily sync
  Future<SyncResult> sync();

  /// Setup the background job
  Future<void> setupDailyJob();

  /// Cancel the background job
  Future<void> cancelDailyJob();
}

// ============================================================================
// API SYNC MODE
// ============================================================================

/// Sync notifications from API daily
class ApiDailySync implements DailySync {
  final NotificationManager _notificationManager;
  final NotificationStorage _storage;
  final String apiUrl;
  final Map<String, String>? headers;
  final Future<List<NotificationItem>> Function() fetchReminders;

  ApiDailySync({
    required this.apiUrl,
    required this.fetchReminders,
    this.headers,
    NotificationManager? notificationManager,
    NotificationStorage? storage,
  }) : _notificationManager = notificationManager ?? NotificationManager(),
       _storage = storage ?? NotificationStorage();

  static const String _taskName = 'api_daily_sync';

  @override
  Future<SyncResult> sync() async {
    try {
      // Fetch today's reminders from API
      final reminders = await fetchReminders();

      // Cache the response for offline fallback
      await _storage.cacheApiReminders(DateTime.now(), reminders);

      // Delete old API notifications
      await _notificationManager.deleteAllBySource(NotificationSource.api);

      // Schedule new notifications
      await _notificationManager.scheduleAll(reminders);

      return SyncResult.success(count: reminders.length);
    } catch (e) {
      // API failed - try to use cache
      final cached = await _storage.getCachedApiReminders(DateTime.now());

      if (cached != null && cached.isNotEmpty) {
        // Use cached data
        await _notificationManager.deleteAllBySource(NotificationSource.api);
        await _notificationManager.scheduleAll(cached);

        return SyncResult.success(count: cached.length, fromCache: true);
      }

      // No cache available - return error
      return SyncResult.failure('Failed to fetch reminders: $e');
    }
  }

  @override
  Future<void> setupDailyJob() async {
    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: const Duration(hours: 24),
      initialDelay: _calculateInitialDelay(),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
  }

  @override
  Future<void> cancelDailyJob() async {
    await Workmanager().cancelByUniqueName(_taskName);
  }

  /// Calculate delay until next midnight ± 2 hours window
  Duration _calculateInitialDelay() {
    final now = DateTime.now();
    var nextMidnight = DateTime(now.year, now.month, now.day + 1);

    // Random offset between -2h and +2h from midnight
    final randomMinutes =
        (DateTime.now().millisecond % 240) - 120; // -120 to +120 minutes
    nextMidnight = nextMidnight.add(Duration(minutes: randomMinutes));

    return nextMidnight.difference(now);
  }

  /// Manual refresh (for pull-to-refresh in UI)
  Future<SyncResult> forceRefresh() async {
    return await sync();
  }
}

// ============================================================================
// USER SYNC MODE
// ============================================================================

/// Sync user-defined recurring notifications daily
class UserDailySync implements DailySync {
  final NotificationManager _notificationManager;
  final NotificationStorage _storage;

  UserDailySync({
    NotificationManager? notificationManager,
    NotificationStorage? storage,
  }) : _notificationManager = notificationManager ?? NotificationManager(),
       _storage = storage ?? NotificationStorage();

  static const String _taskName = 'user_daily_sync';

  @override
  Future<SyncResult> sync() async {
    try {
      // Get all user reminders
      final userReminders = await _storage.getNotificationsBySource(
        NotificationSource.user,
      );

      // Filter active recurring reminders
      final activeRecurring = userReminders
          .where((r) => r.isActive && r.isRecurring && !r.isExpired)
          .toList();

      // Cleanup expired notifications
      await _notificationManager.cleanupExpired();

      // Reschedule all active recurring reminders
      // (This ensures they fire at the correct time today)
      for (final reminder in activeRecurring) {
        await _notificationManager.schedule(reminder);
      }

      return SyncResult.success(count: activeRecurring.length);
    } catch (e) {
      return SyncResult.failure('Failed to sync user reminders: $e');
    }
  }

  @override
  Future<void> setupDailyJob() async {
    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: const Duration(hours: 24),
      initialDelay: _calculateInitialDelay(),
      constraints: Constraints(
        networkType:
            NetworkType.notRequired, // No internet needed for user reminders
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
  }

  @override
  Future<void> cancelDailyJob() async {
    await Workmanager().cancelByUniqueName(_taskName);
  }

  /// Calculate delay until next midnight ± 2 hours window
  Duration _calculateInitialDelay() {
    final now = DateTime.now();
    var nextMidnight = DateTime(now.year, now.month, now.day + 1);

    // Random offset between -2h and +2h from midnight
    final randomMinutes = (DateTime.now().millisecond % 240) - 120;
    nextMidnight = nextMidnight.add(Duration(minutes: randomMinutes));

    return nextMidnight.difference(now);
  }
}

// ============================================================================
// WORKMANAGER CALLBACK DISPATCHER
// ============================================================================

/// This function runs in a separate isolate (background)
/// Must be a top-level function or static method
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Initialize components (they don't persist across isolates)
      final notificationManager = NotificationManager();
      await notificationManager.initialize();

      // Determine which sync to run based on task name
      if (task == 'api_daily_sync') {
        // Get API URL from inputData
        final apiUrl = inputData?['apiUrl'] as String?;
        if (apiUrl == null) {
          return Future.value(false);
        }

        // Note: You'll need to recreate your fetchReminders function here
        // or pass necessary data via inputData
        // For now, this is a placeholder

        return Future.value(true);
      } else if (task == 'user_daily_sync') {
        final userSync = UserDailySync(
          notificationManager: notificationManager,
        );

        final result = await userSync.sync();
        return Future.value(result.success);
      }

      return Future.value(false);
    } catch (e) {
      debugPrint('Background task error: $e');
      return Future.value(false);
    }
  });
}

// ============================================================================
// SYNC MANAGER (Unified Interface)
// ============================================================================

/// Manages daily sync initialization and execution
class SyncManager {
  static SyncManager? _instance;

  SyncManager._();

  factory SyncManager() {
    _instance ??= SyncManager._();
    return _instance!;
  }

  DailySync? _activeSync;
  bool _initialized = false;

  /// Initialize WorkManager
  Future<void> initialize() async {
    if (_initialized) return;

    await Workmanager().initialize(callbackDispatcher);

    _initialized = true;
  }

  /// Setup API sync mode
  Future<void> setupApiSync({
    required String apiUrl,
    required Future<List<NotificationItem>> Function() fetchReminders,
    Map<String, String>? headers,
  }) async {
    await initialize();

    _activeSync = ApiDailySync(
      apiUrl: apiUrl,
      fetchReminders: fetchReminders,
      headers: headers,
    );

    await _activeSync!.setupDailyJob();
  }

  /// Setup User sync mode
  Future<void> setupUserSync() async {
    await initialize();

    _activeSync = UserDailySync();
    await _activeSync!.setupDailyJob();
  }

  /// Manually trigger sync (for testing or pull-to-refresh)
  Future<SyncResult> triggerSync() async {
    if (_activeSync == null) {
      return SyncResult.failure('No sync configured');
    }

    return await _activeSync!.sync();
  }

  /// Cancel current sync job
  Future<void> cancelSync() async {
    if (_activeSync != null) {
      await _activeSync!.cancelDailyJob();
      _activeSync = null;
    }
  }

  /// Check if sync is configured
  bool get isConfigured => _activeSync != null;

  /// Get current sync type
  String get syncType {
    if (_activeSync == null) return 'none';
    if (_activeSync is ApiDailySync) return 'api';
    if (_activeSync is UserDailySync) return 'user';
    return 'unknown';
  }
}

// ============================================================================
// BOOT HANDLER (Reschedule after device restart)
// ============================================================================

/// Call this from your Android BroadcastReceiver
class BootHandler {
  static Future<void> onDeviceBoot() async {
    // Reinitialize notification system
    final notificationManager = NotificationManager();
    await notificationManager.initialize();

    // Reschedule all notifications
    await notificationManager.rescheduleAll();

    // Reinitialize WorkManager
    final syncManager = SyncManager();
    await syncManager.initialize();

    // Note: You'll need to persist which sync mode was active
    // and restore it here. Options:
    // 1. Save sync type to SharedPreferences
    // 2. Check which notifications exist (api vs user) and infer

    debugPrint('Device rebooted - notifications rescheduled');
  }
}
