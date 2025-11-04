// permission_manager.dart

import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'model.dart';

// Import your models
// import 'models/permission_status.dart';

class PermissionManager {
  static PermissionManager? _instance;

  // Singleton pattern
  PermissionManager._();

  factory PermissionManager() {
    _instance ??= PermissionManager._();
    return _instance!;
  }

  // Device info instance
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // ============================================================================
  // PERMISSION CHECKING
  // ============================================================================

  /// Check all required permissions status
  Future<AppPermissionStatus> checkAllPermissions() async {
    final notificationsGranted = await _checkNotificationPermission();
    final exactAlarmsGranted = await _checkExactAlarmPermission();
    final batteryOptimized = await _isBatteryOptimized();
    final needsSpecialGuidance = await isAggressiveDevice();
    final deviceInfo = await _getDeviceInfo();

    return AppPermissionStatus(
      notificationsGranted: notificationsGranted,
      exactAlarmsGranted: exactAlarmsGranted,
      batteryOptimized: batteryOptimized,
      needsSpecialGuidance: needsSpecialGuidance,
      deviceInfo: deviceInfo,
    );
  }

  /// Check notification permission
  Future<bool> _checkNotificationPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      // Android 13+ requires explicit permission
      if (androidInfo.version.sdkInt >= 33) {
        final status = await Permission.notification.status;
        return status.isGranted;
      }
      // Below Android 13, notifications are granted by default
      return true;
    }
    return false;
  }

  /// Check exact alarm permission
  Future<bool> _checkExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      // Android 12+ requires exact alarm permission
      if (androidInfo.version.sdkInt >= 31) {
        final status = await Permission.scheduleExactAlarm.status;
        return status.isGranted;
      }
      // Below Android 12, exact alarms work by default
      return true;
    }
    return false;
  }

  /// Check if battery optimization is enabled (restricts background work)
  Future<bool> _isBatteryOptimized() async {
    if (Platform.isAndroid) {
      final status = await Permission.ignoreBatteryOptimizations.status;
      // If granted, battery optimization is DISABLED (which is what we want)
      return !status.isGranted;
    }
    return false;
  }

  // ============================================================================
  // PERMISSION REQUESTING
  // ============================================================================

  /// Request all necessary permissions
  Future<AppPermissionStatus> requestAllPermissions() async {
    // Request notification permission
    await _requestNotificationPermission();

    // Request exact alarm permission
    await _requestExactAlarmPermission();

    // Check final status
    return await checkAllPermissions();
  }

  /// Request notification permission
  Future<bool> _requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        final status = await Permission.notification.request();
        return status.isGranted;
      }
      return true;
    }
    return false;
  }

  /// Request exact alarm permission
  /// Note: This opens system settings, doesn't show a dialog
  Future<bool> _requestExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 31) {
        final status = await Permission.scheduleExactAlarm.status;

        if (status.isDenied) {
          // Open system settings for exact alarms
          await openAlarmSettings();

          // Wait a bit for user to return
          await Future.delayed(const Duration(seconds: 1));

          // Check again
          final newStatus = await Permission.scheduleExactAlarm.status;
          return newStatus.isGranted;
        }

        return status.isGranted;
      }
      return true;
    }
    return false;
  }

  // ============================================================================
  // OPEN SYSTEM SETTINGS
  // ============================================================================

  /// Open alarm & reminders settings page
  Future<void> openAlarmSettings() async {
    try {
      await AppSettings.openAppSettings(type: AppSettingsType.alarm);
    } catch (e) {
      // Fallback to general app settings
      await AppSettings.openAppSettings();
    }
  }

  /// Open battery optimization settings
  Future<void> openBatterySettings() async {
    try {
      await AppSettings.openAppSettings(
        type: AppSettingsType.batteryOptimization,
      );
    } catch (e) {
      // Fallback to general app settings
      await AppSettings.openAppSettings();
    }
  }

  /// Open notification settings
  Future<void> openNotificationSettings() async {
    await AppSettings.openAppSettings(type: AppSettingsType.notification);
  }

  /// Open general app settings
  Future<void> openAppSettings() async {
    await AppSettings.openAppSettings();
  }

  // ============================================================================
  // DEVICE DETECTION
  // ============================================================================

  /// List of aggressive device manufacturers
  static const List<String> _aggressiveManufacturers = [
    'tecno',
    'infinix',
    'itel',
    'xiaomi',
    'redmi',
    'poco',
    'oppo',
    'realme',
    'vivo',
    'oneplus',
    'huawei',
    'honor',
    'samsung', // Some Samsung devices have aggressive optimization
  ];

  /// Check if device is known for aggressive battery optimization
  Future<bool> isAggressiveDevice() async {
    if (!Platform.isAndroid) return false;

    try {
      final androidInfo = await _deviceInfo.androidInfo;
      final manufacturer = androidInfo.manufacturer.toLowerCase();

      return _aggressiveManufacturers.any(
        (brand) => manufacturer.contains(brand),
      );
    } catch (e) {
      return false;
    }
  }

  /// Get device information string
  Future<String> _getDeviceInfo() async {
    if (!Platform.isAndroid) return 'Unknown';

    try {
      final androidInfo = await _deviceInfo.androidInfo;
      return '${androidInfo.manufacturer} ${androidInfo.model} (Android ${androidInfo.version.release})';
    } catch (e) {
      return 'Unknown Android Device';
    }
  }

  /// Get specific manufacturer
  Future<String> getManufacturer() async {
    if (!Platform.isAndroid) return 'Unknown';

    try {
      final androidInfo = await _deviceInfo.androidInfo;
      return androidInfo.manufacturer;
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Check if device is HiOS (Tecno/Infinix/Itel)
  Future<bool> isHiOS() async {
    final manufacturer = await getManufacturer();
    return [
      'tecno',
      'infinix',
      'itel',
    ].any((brand) => manufacturer.toLowerCase().contains(brand));
  }

  /// Check if device is MIUI (Xiaomi/Redmi/Poco)
  Future<bool> isMIUI() async {
    final manufacturer = await getManufacturer();
    return [
      'xiaomi',
      'redmi',
      'poco',
    ].any((brand) => manufacturer.toLowerCase().contains(brand));
  }

  // ============================================================================
  // GUIDANCE MESSAGES
  // ============================================================================

  /// Get device-specific guidance for battery optimization
  Future<String> getBatteryGuidance() async {
    if (await isHiOS()) {
      return '''
For Tecno/Infinix/Itel devices (HiOS):

1. Go to Settings → Battery
2. Find this app in the list
3. Set to "Unrestricted" or "No restrictions"

Also enable:
4. Settings → App Management → Auto Start
5. Enable auto-start for this app

This ensures reminders work reliably.
''';
    }

    if (await isMIUI()) {
      return '''
For Xiaomi/Redmi/Poco devices (MIUI):

1. Go to Settings → Apps → Manage apps
2. Find this app
3. Battery saver → No restrictions
4. Autostart → Enable
5. Battery optimization → Don't optimize

This ensures reminders work reliably.
''';
    }

    // Generic guidance
    return '''
To ensure reliable reminders:

1. Go to Settings → Apps
2. Find this app
3. Battery → Unrestricted
4. Disable battery optimization

This allows the app to send reminders on time.
''';
  }

  /// Get permission explanation text
  String getPermissionExplanation(String permissionType) {
    switch (permissionType) {
      case 'notification':
        return 'We need permission to show you medication reminders at the right time.';

      case 'exact_alarm':
        return 'We need permission to schedule exact-time reminders. This ensures your medication reminders arrive precisely when scheduled.';

      case 'battery':
        return 'Disabling battery optimization ensures reminders work even when your phone is idle or the app is closed.';

      default:
        return 'This permission helps ensure reliable reminders.';
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Check if we should show permission rationale
  Future<bool> shouldShowRationale(Permission permission) async {
    return await permission.shouldShowRequestRationale;
  }

  /// Check if permission is permanently denied
  Future<bool> isPermanentlyDenied(Permission permission) async {
    return await permission.isPermanentlyDenied;
  }

  /// Get Android SDK version
  Future<int> getAndroidSdkVersion() async {
    if (!Platform.isAndroid) return 0;

    try {
      final androidInfo = await _deviceInfo.androidInfo;
      return androidInfo.version.sdkInt;
    } catch (e) {
      return 0;
    }
  }

  // ============================================================================
  // DIAGNOSTIC METHODS
  // ============================================================================

  /// Get detailed permission report (useful for debugging)
  Future<Map<String, dynamic>> getPermissionReport() async {
    final status = await checkAllPermissions();
    final sdkVersion = await getAndroidSdkVersion();
    final manufacturer = await getManufacturer();
    final isAggressive = await isAggressiveDevice();

    return {
      'notifications_granted': status.notificationsGranted,
      'exact_alarms_granted': status.exactAlarmsGranted,
      'battery_optimized': status.batteryOptimized,
      'needs_special_guidance': status.needsSpecialGuidance,
      'device_info': status.deviceInfo,
      'manufacturer': manufacturer,
      'android_sdk': sdkVersion,
      'is_aggressive_device': isAggressive,
      'is_hios': await isHiOS(),
      'is_miui': await isMIUI(),
      'all_granted': status.allGranted,
      'fully_configured': status.isFullyConfigured,
      'missing_permissions': status.missingPermissions,
    };
  }

  /// Print diagnostic information (for debugging)
  Future<void> printDiagnostics() async {
    final report = await getPermissionReport();
    debugPrint('=== Permission Diagnostics ===');
    report.forEach((key, value) {
      debugPrint('$key: $value');
    });
    debugPrint('============================');
  }
}
