import 'package:flutter/material.dart';
import 'my_notification_package.dart'; // Your NotificationService import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize(
    onNotificationTap: (payload) {
      debugPrint('User tapped notification → $payload');
    },
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notification Test',
      home: Scaffold(
        appBar: AppBar(title: const Text('Scheduled Notifications')),
        body: const NotificationTester(),
      ),
    );
  }
}

class NotificationTester extends StatelessWidget {
  const NotificationTester({super.key});

  DateTime _todayAt(int hour, int minute) {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    if (target.isBefore(now)) {
      // If time already passed today, schedule for tomorrow
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  Future<void> _scheduleAll() async {
    final now = DateTime.now();
    final tests = [
      {
        'title': '1-minute Test',
        'body': 'This will fire in 1 minute.',
        'time': now.add(const Duration(minutes: 1)),
      },
      {
        'title': '5-minute Test',
        'body': 'This will fire in 5 minutes.',
        'time': now.add(const Duration(minutes: 5)),
      },
      {
        'title': '10-minute Test',
        'body': 'This will fire in 10 minutes.',
        'time': now.add(const Duration(minutes: 10)),
      },
      {
        'title': '1-hour Test',
        'body': 'This will fire in 1 hour.',
        'time': now.add(const Duration(hours: 1)),
      },
      {
        'title': '6 PM Reminder',
        'body': 'Scheduled for 6 PM.',
        'time': _todayAt(18, 0),
      },
      {
        'title': '8 PM Reminder',
        'body': 'Scheduled for 8 PM.',
        'time': _todayAt(20, 0),
      },
    ];

    for (var t in tests) {
      await NotificationService().scheduleNotification(
        title: t['title'] as String,
        body: t['body'] as String,
        scheduledTime: t['time'] as DateTime,
      );
      debugPrint('✅ Scheduled: ${t['title']} → ${t['time']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(24),
        children: [
          ElevatedButton(
            onPressed: () {
              NotificationService().showInstantNotification(
                title: 'Instant Notification',
                body: 'This fired immediately!',
                payload: 'instant',
              );
            },
            child: const Text('Show Instant'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _scheduleAll,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Schedule All Notifications'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => NotificationService().cancelAll(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel All Notifications'),
          ),
        ],
      ),
    );
  }
}
