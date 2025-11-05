// lib/native_alarm_manager.dart
//
// Dart wrapper for native Android alarm system.
// Provides a clean interface to interact with Kotlin AlarmScheduler.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeAlarmManager {
  static const platform = MethodChannel('com.example.test/native_alarms');

  /// Schedule an exact alarm using native Android AlarmManager
  ///
  /// [id] - Unique positive integer ID for this alarm
  /// [title] - Notification title
  /// [body] - Notification body text
  /// [scheduledTime] - When to fire the alarm
  /// [payload] - Optional data to pass back when tapped
  ///
  /// Returns true if scheduled successfully
  static Future<bool> scheduleAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    try {
      debugPrint('');
      debugPrint(
        '╔═══════════════════════════════════════════════════════════╗',
      );
      debugPrint(
        '║ NATIVE ALARM SCHEDULER                                    ║',
      );
      debugPrint(
        '╚═══════════════════════════════════════════════════════════╝',
      );
      debugPrint('ID: $id');
      debugPrint('Title: $title');
      debugPrint('Body: $body');
      debugPrint('Scheduled: $scheduledTime');
      debugPrint('Payload: ${payload ?? "null"}');
      debugPrint('Timestamp: ${scheduledTime.millisecondsSinceEpoch}');

      final result = await platform.invokeMethod('scheduleAlarm', {
        'id': id,
        'title': title,
        'body': body,
        'timestamp': scheduledTime.millisecondsSinceEpoch,
        'payload': payload,
      });

      final success = result as bool;

      if (success) {
        debugPrint('✅ Native alarm scheduled successfully');
      } else {
        debugPrint('❌ Native alarm scheduling returned false');
      }

      debugPrint(
        '╚═══════════════════════════════════════════════════════════╝',
      );
      debugPrint('');

      return success;
    } on PlatformException catch (e) {
      debugPrint('❌ Platform exception in scheduleAlarm:');
      debugPrint('   Code: ${e.code}');
      debugPrint('   Message: ${e.message}');
      debugPrint('   Details: ${e.details}');
      return false;
    } catch (e, stackTrace) {
      debugPrint('❌ Unexpected error in scheduleAlarm: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Cancel a specific alarm by ID
  static Future<bool> cancelAlarm(int id) async {
    try {
      debugPrint('🗑️ Cancelling native alarm: ID=$id');

      final result = await platform.invokeMethod('cancelAlarm', id);
      final success = result as bool;

      if (success) {
        debugPrint('✅ Native alarm cancelled: ID=$id');
      } else {
        debugPrint('⚠️ Native alarm cancel returned false: ID=$id');
      }

      return success;
    } on PlatformException catch (e) {
      debugPrint('❌ Platform exception in cancelAlarm: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Error cancelling native alarm: $e');
      return false;
    }
  }

  /// Cancel all scheduled alarms
  static Future<bool> cancelAllAlarms() async {
    try {
      debugPrint('🗑️ Cancelling all native alarms...');

      final result = await platform.invokeMethod('cancelAllAlarms');
      final success = result as bool;

      if (success) {
        debugPrint('✅ All native alarms cancelled');
      } else {
        debugPrint('⚠️ Cancel all returned false');
      }

      return success;
    } on PlatformException catch (e) {
      debugPrint('❌ Platform exception in cancelAllAlarms: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Error cancelling all native alarms: $e');
      return false;
    }
  }

  /// Get all currently scheduled alarms
  static Future<List<NativeAlarmInfo>> getAllScheduledAlarms() async {
    try {
      final result = await platform.invokeMethod('getAllScheduledAlarms');
      final List<dynamic> alarmMaps = result as List<dynamic>;

      final alarms = alarmMaps.map((map) {
        final m = map as Map<dynamic, dynamic>;
        return NativeAlarmInfo(
          id: m['id'] as int,
          title: m['title'] as String,
          body: m['body'] as String,
          timestamp: DateTime.fromMillisecondsSinceEpoch(m['timestamp'] as int),
          payload: m['payload'] as String?,
        );
      }).toList();

      debugPrint('📊 Retrieved ${alarms.length} scheduled native alarms');
      return alarms;
    } on PlatformException catch (e) {
      debugPrint('❌ Platform exception in getAllScheduledAlarms: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('❌ Error getting native alarms: $e');
      return [];
    }
  }

  /// Check if exact alarm permission is granted (Android 12+)
  static Future<bool> canScheduleExactAlarms() async {
    try {
      final result = await platform.invokeMethod('canScheduleExactAlarms');
      final canSchedule = result as bool;

      if (canSchedule) {
        debugPrint('✅ Exact alarm permission granted');
      } else {
        debugPrint('⚠️ Exact alarm permission NOT granted');
      }

      return canSchedule;
    } on PlatformException catch (e) {
      debugPrint('❌ Platform exception checking permission: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Error checking permission: $e');
      return false;
    }
  }

  /// Open system settings for exact alarm permission (Android 12+)
  static Future<bool> openAlarmSettings() async {
    try {
      final result = await platform.invokeMethod('openAlarmSettings');
      return result as bool;
    } on PlatformException catch (e) {
      debugPrint('❌ Platform exception opening settings: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Error opening settings: $e');
      return false;
    }
  }

  /// Show a native test notification immediately (uses NotificationHelper)
  static Future<bool> showTestNotification({
    String? title,
    String? body,
  }) async {
    try {
      final result = await platform.invokeMethod('showTestNotification', {
        'title': title ?? 'Test Notification',
        'body': body ?? 'This is a native test notification',
      });
      return result as bool;
    } on PlatformException catch (e) {
      debugPrint('❌ Platform exception in showTestNotification: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Error in showTestNotification: $e');
      return false;
    }
  }

  /// Comprehensive health check
  static Future<NativeAlarmHealth> checkHealth() async {
    try {
      final canSchedule = await canScheduleExactAlarms();
      final scheduledAlarms = await getAllScheduledAlarms();

      return NativeAlarmHealth(
        canScheduleExactAlarms: canSchedule,
        scheduledCount: scheduledAlarms.length,
        scheduledAlarms: scheduledAlarms,
        isHealthy: canSchedule,
      );
    } catch (e) {
      debugPrint('❌ Error in health check: $e');
      return NativeAlarmHealth(
        canScheduleExactAlarms: false,
        scheduledCount: 0,
        scheduledAlarms: [],
        isHealthy: false,
        error: e.toString(),
      );
    }
  }
}

/// Information about a scheduled native alarm
class NativeAlarmInfo {
  final int id;
  final String title;
  final String body;
  final DateTime timestamp;
  final String? payload;

  NativeAlarmInfo({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.payload,
  });

  @override
  String toString() {
    return 'NativeAlarmInfo(id: $id, title: $title, timestamp: $timestamp)';
  }
}

/// Health status of native alarm system
class NativeAlarmHealth {
  final bool canScheduleExactAlarms;
  final int scheduledCount;
  final List<NativeAlarmInfo> scheduledAlarms;
  final bool isHealthy;
  final String? error;

  NativeAlarmHealth({
    required this.canScheduleExactAlarms,
    required this.scheduledCount,
    required this.scheduledAlarms,
    required this.isHealthy,
    this.error,
  });

  @override
  String toString() {
    return '''
Native Alarm Health:
- Can schedule: $canScheduleExactAlarms
- Scheduled count: $scheduledCount
- Healthy: $isHealthy
- Error: ${error ?? "none"}
''';
  }
}
