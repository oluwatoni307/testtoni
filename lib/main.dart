import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestAllPermissions();
  runApp(const MyApp());
}

/// Request all important Android permissions:
/// - Notifications (Android 13+)
/// - Exact alarms
/// - Battery optimization exemption
Future<void> requestAllPermissions() async {
  if (!Platform.isAndroid) return;

  // ✅ Ask for POST_NOTIFICATIONS (Android 13+)
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }

  // ✅ Request exact alarm permission (Android 13+)
  try {
    const platform = MethodChannel('alarm_channel');
    final bool? granted = await platform.invokeMethod(
      'checkExactAlarmPermission',
    );
    if (granted == false) {
      final intent = AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
        package: 'com.example.test', // <-- use your real package name
      );
      await intent.launch();
    }
  } catch (_) {
    // fallback – ignore silently
  }

  // ✅ Request battery optimization disable
  try {
    final intent = AndroidIntent(
      action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
      data: 'package:com.example.test', // <-- use your real package name
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
  } catch (_) {
    // ignore
  }
}

/// Main App
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Persistent Notifications',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AlarmHome(),
    );
  }
}

/// Home Screen for testing alarms
class AlarmHome extends StatefulWidget {
  const AlarmHome({super.key});

  @override
  State<AlarmHome> createState() => _AlarmHomeState();
}

class _AlarmHomeState extends State<AlarmHome> {
  static const platform = MethodChannel('alarm_channel');

  Future<void> _scheduleAlarm(Duration delay, String label) async {
    try {
      await platform.invokeMethod('scheduleAlarm', {
        'delaySeconds': delay.inSeconds,
        'message': label,
      });
      debugPrint('⏰ Scheduled "$label" after ${delay.inMinutes} min');
    } on PlatformException catch (e) {
      debugPrint('❌ Failed to schedule: ${e.message}');
    }
  }

  Future<void> _scheduleAll() async {
    await _scheduleAlarm(const Duration(minutes: 1), '1 Minute Alarm');
    await _scheduleAlarm(const Duration(minutes: 5), '5 Minute Alarm');
    await _scheduleAlarm(const Duration(minutes: 10), '10 Minute Alarm');
    await _scheduleAlarm(const Duration(hours: 1), '1 Hour Alarm');
    debugPrint('✅ All alarms scheduled.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Persistent Alarm Test')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () =>
                  _scheduleAlarm(const Duration(seconds: 5), 'Instant (5 sec)'),
              child: const Text('Schedule 5s Alarm'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _scheduleAll,
              child: const Text('Schedule All'),
            ),
          ],
        ),
      ),
    );
  }
}
