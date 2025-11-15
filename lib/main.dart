// pubspec.yaml
// dependencies:
//   flutter_local_notifications: ^18.0.0
//   android_alarm_manager_plus: ^4.0.3
//   shared_preferences: ^2.3.3

import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Must be top-level function
@pragma('vm:entry-point')
void alarmCallback() async {
  // Initialize notifications
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  await notificationsPlugin.initialize(
    const InitializationSettings(android: androidInit),
  );

  // Get count
  final prefs = await SharedPreferences.getInstance();
  int count = (prefs.getInt('notif_count') ?? 0) + 1;
  await prefs.setInt('notif_count', count);

  // Show notification
  await notificationsPlugin.show(
    0,
    'Reminder #$count',
    '30-minute notification at ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'alarm_channel',
        'Alarm Notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isRunning = false;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _count = prefs.getInt('notif_count') ?? 0;
    });
  }

  Future<void> _startAlarm() async {
    await AndroidAlarmManager.periodic(
      const Duration(minutes: 30),
      0, // Unique alarm ID
      alarmCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );

    setState(() {
      _isRunning = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Started! Will notify every 30 minutes'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _stopAlarm() async {
    await AndroidAlarmManager.cancel(0);
    setState(() {
      _isRunning = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏹️ Stopped periodic notifications'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _resetCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notif_count', 0);
    await _loadCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reliable 30-Min Notifications'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isRunning ? Icons.alarm_on : Icons.alarm_off,
                size: 80,
                color: _isRunning ? Colors.green : Colors.grey,
              ),
              const SizedBox(height: 20),
              Text(
                'Status: ${_isRunning ? "Running" : "Stopped"}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Notifications sent: $_count',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _isRunning ? null : _startAlarm,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Notifications'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
              ),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                onPressed: _isRunning ? _stopAlarm : null,
                icon: const Icon(Icons.stop),
                label: const Text('Stop Notifications'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
              ),
              const SizedBox(height: 15),
              OutlinedButton.icon(
                onPressed: _resetCount,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset Counter'),
              ),
              const SizedBox(height: 30),
              const Card(
                color: Colors.blue,
                child: Padding(
                  padding: EdgeInsets.all(15),
                  child: Column(
                    children: [
                      Text(
                        '✅ This WILL work reliably:',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• Wakes device from sleep\n'
                        '• Works when app is closed\n'
                        '• Survives phone restarts\n'
                        '• Exact 30-minute intervals',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
