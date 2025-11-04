// notification_item.dart

import 'dart:convert';
import 'package:flutter/material.dart';

enum NotificationSource { api, user }

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final NotificationSource source;

  // Scheduling options
  final DateTime? oneTimeDate; // For one-time notifications
  final TimeOfDay? recurringTime; // For daily recurring (e.g., 9:00 AM)
  final DateTime? endDate; // When recurring should stop

  // Metadata
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? extras; // Flexible for future extensions

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.source,
    this.oneTimeDate,
    this.recurringTime,
    this.endDate,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.extras,
  }) : assert(
         oneTimeDate != null || recurringTime != null,
         'Either oneTimeDate or recurringTime must be provided',
       );

  // Check if this notification is expired
  bool get isExpired {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  // Check if this is a recurring notification
  bool get isRecurring => recurringTime != null;

  // Get next scheduled time for recurring notifications
  DateTime? get nextScheduledTime {
    if (recurringTime == null) return oneTimeDate;

    final now = DateTime.now();
    var scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      recurringTime!.hour,
      recurringTime!.minute,
    );

    // If time has passed today, schedule for tomorrow
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    // Check if past end date
    if (endDate != null && scheduled.isAfter(endDate!)) {
      return null; // Expired
    }

    return scheduled;
  }

  // Copy with method for easy updates
  NotificationItem copyWith({
    String? id,
    String? title,
    String? body,
    NotificationSource? source,
    DateTime? oneTimeDate,
    TimeOfDay? recurringTime,
    DateTime? endDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? extras,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      source: source ?? this.source,
      oneTimeDate: oneTimeDate ?? this.oneTimeDate,
      recurringTime: recurringTime ?? this.recurringTime,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      extras: extras ?? this.extras,
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'source': source.name,
      'oneTimeDate': oneTimeDate?.millisecondsSinceEpoch,
      'recurringTime': recurringTime != null
          ? '${recurringTime!.hour.toString().padLeft(2, '0')}:${recurringTime!.minute.toString().padLeft(2, '0')}'
          : null,
      'endDate': endDate?.millisecondsSinceEpoch,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'extras': extras,
    };
  }

  // Create from JSON
  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    TimeOfDay? parseRecurringTime(String? timeStr) {
      if (timeStr == null) return null;
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    // Support both camelCase and snake_case keys to be compatible with
    // older/other versions of the DB or external JSON sources.
    final dynamic oneTimeRaw = json['oneTimeDate'] ?? json['one_time_date'];
    final dynamic recurringRaw =
        json['recurringTime'] ?? json['recurring_time'];
    final dynamic endDateRaw = json['endDate'] ?? json['end_date'];
    final dynamic isActiveRaw = json['isActive'] ?? json['is_active'];
    final dynamic createdAtRaw = json['createdAt'] ?? json['created_at'];
    final dynamic updatedAtRaw = json['updatedAt'] ?? json['updated_at'];
    final dynamic extrasRaw = json['extras'];

    final DateTime? oneTime = oneTimeRaw != null
        ? DateTime.fromMillisecondsSinceEpoch(oneTimeRaw as int)
        : null;

    final TimeOfDay? recurring = parseRecurringTime(recurringRaw as String?);

    final DateTime? end = endDateRaw != null
        ? DateTime.fromMillisecondsSinceEpoch(endDateRaw as int)
        : null;

    final bool active = isActiveRaw == 1 || isActiveRaw == true;

    final DateTime created = DateTime.fromMillisecondsSinceEpoch(
      createdAtRaw as int,
    );

    final DateTime? updated = updatedAtRaw != null
        ? DateTime.fromMillisecondsSinceEpoch(updatedAtRaw as int)
        : null;

    Map<String, dynamic>? extrasMap;
    if (extrasRaw is String) {
      try {
        extrasMap = extrasRaw.isNotEmpty
            ? Map<String, dynamic>.from(jsonDecode(extrasRaw))
            : null;
      } catch (_) {
        extrasMap = null;
      }
    } else if (extrasRaw is Map) {
      extrasMap = Map<String, dynamic>.from(extrasRaw);
    } else {
      extrasMap = null;
    }

    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      source: NotificationSource.values.firstWhere(
        (e) => e.name == json['source'],
      ),
      oneTimeDate: oneTime,
      recurringTime: recurring,
      endDate: end,
      isActive: active,
      createdAt: created,
      updatedAt: updated,
      extras: extrasMap,
    );
  }

  @override
  String toString() {
    return 'NotificationItem(id: $id, title: $title, source: ${source.name}, '
        'isRecurring: $isRecurring, nextScheduled: $nextScheduledTime)';
  }
}

// ============================================================================
// notification_settings.dart
// ============================================================================

enum NotificationPriority { low, medium, high, urgent }

class NotificationSettings {
  final bool vibration;
  final bool sound;
  final NotificationPriority priority;
  final String? soundFile; // Custom sound file path (optional)

  const NotificationSettings({
    this.vibration = true,
    this.sound = true,
    this.priority = NotificationPriority.high,
    this.soundFile,
  });

  // Copy with method
  NotificationSettings copyWith({
    bool? vibration,
    bool? sound,
    NotificationPriority? priority,
    String? soundFile,
  }) {
    return NotificationSettings(
      vibration: vibration ?? this.vibration,
      sound: sound ?? this.sound,
      priority: priority ?? this.priority,
      soundFile: soundFile ?? this.soundFile,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'vibration': vibration ? 1 : 0,
      'sound': sound ? 1 : 0,
      'priority': priority.name,
      'soundFile': soundFile,
    };
  }

  // Create from JSON
  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      vibration: json['vibration'] == 1,
      sound: json['sound'] == 1,
      priority: NotificationPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => NotificationPriority.high,
      ),
      soundFile: json['soundFile'] as String?,
    );
  }

  // Default settings
  static const NotificationSettings defaults = NotificationSettings();

  @override
  String toString() {
    return 'NotificationSettings(vibration: $vibration, sound: $sound, priority: ${priority.name})';
  }
}

// ============================================================================
// app_permission_status.dart
// ============================================================================

// Renamed from PermissionStatus to avoid conflict with permission_handler package
class AppPermissionStatus {
  final bool notificationsGranted;
  final bool exactAlarmsGranted;
  final bool batteryOptimized; // true = restricted, false = unrestricted
  final bool needsSpecialGuidance; // For HiOS, MIUI, etc.
  final String? deviceInfo; // Brand/model info

  const AppPermissionStatus({
    required this.notificationsGranted,
    required this.exactAlarmsGranted,
    required this.batteryOptimized,
    this.needsSpecialGuidance = false,
    this.deviceInfo,
  });

  // Check if all critical permissions are granted
  bool get allGranted => notificationsGranted && exactAlarmsGranted;

  // Check if setup is complete (including battery optimization)
  bool get isFullyConfigured => allGranted && !batteryOptimized;

  // Get list of missing permissions
  List<String> get missingPermissions {
    final missing = <String>[];
    if (!notificationsGranted) missing.add('Notifications');
    if (!exactAlarmsGranted) missing.add('Exact Alarms');
    if (batteryOptimized) missing.add('Battery Optimization');
    return missing;
  }

  @override
  String toString() {
    return 'AppPermissionStatus(notifications: $notificationsGranted, '
        'exactAlarms: $exactAlarmsGranted, batteryOptimized: $batteryOptimized, '
        'specialGuidance: $needsSpecialGuidance)';
  }
}

// ============================================================================
// sync_result.dart
// ============================================================================

class SyncResult {
  final bool success;
  final int scheduledCount;
  final String? errorMessage;
  final DateTime syncTime;
  final bool usedCache; // true if fallback to cache was used

  const SyncResult({
    required this.success,
    required this.scheduledCount,
    this.errorMessage,
    required this.syncTime,
    this.usedCache = false,
  });

  factory SyncResult.success({required int count, bool fromCache = false}) {
    return SyncResult(
      success: true,
      scheduledCount: count,
      syncTime: DateTime.now(),
      usedCache: fromCache,
    );
  }

  factory SyncResult.failure(String error) {
    return SyncResult(
      success: false,
      scheduledCount: 0,
      errorMessage: error,
      syncTime: DateTime.now(),
    );
  }

  @override
  String toString() {
    if (success) {
      return 'SyncResult(✓ $scheduledCount notifications scheduled${usedCache ? ' from cache' : ''})';
    }
    return 'SyncResult(✗ $errorMessage)';
  }
}
