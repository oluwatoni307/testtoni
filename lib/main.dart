// pubspec.yaml dependencies:
// dependencies:
//   flutter:
//     sdk: flutter
//   android_alarm_manager_plus: ^4.0.3
//   shared_preferences: ^2.2.2
//   permission_handler: ^11.0.1

// main.dart
import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the alarm manager
  await AndroidAlarmManager.initialize();
  
  runApp(const MyApp());
}

// IMPORTANT: Must be a top-level function with @pragma annotation
@pragma('vm:entry-point')
void alarmCallback() {
  print('⏰ ALARM TRIGGERED! Time: ${DateTime.now()}');
  _saveAlarmTriggered();
}

void _saveAlarmTriggered() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('last_alarm_triggered', DateTime.now().toString());
  print('Alarm trigger time saved');
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alarm App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AlarmHomePage(),
    );
  }
}

class AlarmHomePage extends StatefulWidget {
  const AlarmHomePage({Key? key}) : super(key: key);

  @override
  State<AlarmHomePage> createState() => _AlarmHomePageState();
}

class _AlarmHomePageState extends State<AlarmHomePage> {
  static const int alarmId = 123;
  DateTime? scheduledTime;
  String statusMessage = 'No alarm set';
  bool isAlarmSet = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _loadAlarmStatus();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Check Android version
      if (await _isAndroid12OrHigher()) {
        // Request SCHEDULE_EXACT_ALARM permission (Android 12+)
        var status = await Permission.scheduleExactAlarm.status;
        
        if (!status.isGranted) {
          _showSnackBar('⚠️ Please grant exact alarm permission for reliability');
          // This will open the system settings
          await Permission.scheduleExactAlarm.request();
        }
      }
    }
  }

  Future<bool> _isAndroid12OrHigher() async {
    // Android 12 is API level 31
    return true; // Simplified - in production check Build.VERSION.SDK_INT
  }

  Future<void> _loadAlarmStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTime = prefs.getString('alarm_time');
    final lastTriggered = prefs.getString('last_alarm_triggered');
    
    if (savedTime != null) {
      final time = DateTime.parse(savedTime);
      if (time.isAfter(DateTime.now())) {
        setState(() {
          scheduledTime = time;
          isAlarmSet = true;
          statusMessage = 'Alarm set for ${_formatDateTime(time)}';
        });
      } else {
        await prefs.remove('alarm_time');
      }
    }
    
    if (lastTriggered != null) {
      print('Last alarm triggered at: $lastTriggered');
    }
  }

  Future<void> _setAlarm() async {
    try {
      // Calculate time 1 hour from now
      final now = DateTime.now();
      final alarmTime = now.add(const Duration(hours: 1));
      
      // CRITICAL: Use alarmClock: true for maximum reliability
      // This uses setAlarmClock() which bypasses battery optimization
      final success = await AndroidAlarmManager.oneShotAt(
        alarmTime,
        alarmId,
        alarmCallback,
        alarmClock: true,  // Uses setAlarmClock() - shows icon in status bar
        exact: true,       // Exact timing
        wakeup: true,      // Wake device from sleep
        rescheduleOnReboot: true, // Survive reboots
      );

      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('alarm_time', alarmTime.toString());

        setState(() {
          scheduledTime = alarmTime;
          isAlarmSet = true;
          statusMessage = 'Alarm set for ${_formatDateTime(alarmTime)}';
        });

        _showSnackBar('✅ Alarm set! You\'ll see a clock icon in status bar');
      } else {
        _showSnackBar('❌ Failed to set alarm - check permissions');
      }
    } catch (e) {
      _showSnackBar('Error: $e');
      print('Error setting alarm: $e');
    }
  }

  Future<void> _cancelAlarm() async {
    try {
      await AndroidAlarmManager.cancel(alarmId);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('alarm_time');

      setState(() {
        scheduledTime = null;
        isAlarmSet = false;
        statusMessage = 'No alarm set';
      });

      _showSnackBar('🔕 Alarm cancelled');
    } catch (e) {
      _showSnackBar('Error: $e');
      print('Error cancelling alarm: $e');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _getTimeRemaining() {
    if (scheduledTime == null) return '';
    
    final now = DateTime.now();
    final difference = scheduledTime!.difference(now);
    
    if (difference.isNegative) return 'Alarm should have triggered';
    
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    final seconds = difference.inSeconds.remainder(60);
    
    return '${hours}h ${minutes}m ${seconds}s remaining';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _openBatterySettings() {
    _showSnackBar('Opening battery settings...');
    // On Infinix/Tecno: Settings → Battery → App Launch Management
    // This varies by manufacturer
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('1-Hour Alarm'),
        elevation: 2,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isAlarmSet ? Icons.alarm_on : Icons.alarm_off,
                size: 100,
                color: isAlarmSet ? Colors.blue : Colors.grey,
              ),
              const SizedBox(height: 32),
              Text(
                statusMessage,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (isAlarmSet) ...[
                Text(
                  _getTimeRemaining(),
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Set for: ${scheduledTime != null ? _formatDateTime(scheduledTime!) : ""}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: isAlarmSet ? null : _setAlarm,
                icon: const Icon(Icons.add_alarm, size: 28),
                label: const Text('Set Alarm (1 Hour)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 20,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (isAlarmSet)
                OutlinedButton.icon(
                  onPressed: _cancelAlarm,
                  icon: const Icon(Icons.alarm_off),
                  label: const Text('Cancel Alarm'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.info_outline, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'For Infinix/Tecno/Xiaomi Phones:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Go to Settings → Battery\n'
                      '2. Find "App Launch Management"\n'
                      '3. Enable manual management for this app\n'
                      '4. Turn ON all permissions',
                      style: TextStyle(fontSize: 12),
                      textAlign: TextAlign.left,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
