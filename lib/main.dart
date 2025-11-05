import 'package:flutter/material.dart';
import 'my_notification_package.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService().initialize(
    onNotificationTap: (payload) {
      debugPrint('🔔 User tapped notification → $payload');
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
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const NotificationTester(),
    );
  }
}

class NotificationTester extends StatelessWidget {
  const NotificationTester({super.key});

  Future<void> _scheduleAll() async {
    final now = DateTime.now();
    final notifier = NotificationService();

    // 1 minute
    await notifier.scheduleNotification(
      id: 1,
      title: '1 Minute Notification',
      body: 'This fired after 1 minute!',
      scheduledTime: now.add(const Duration(minutes: 1)),
    );

    // 5 minutes
    await notifier.scheduleNotification(
      id: 2,
      title: '5 Minute Notification',
      body: 'This fired after 5 minutes!',
      scheduledTime: now.add(const Duration(minutes: 5)),
    );

    // 10 minutes
    await notifier.scheduleNotification(
      id: 3,
      title: '10 Minute Notification',
      body: 'This fired after 10 minutes!',
      scheduledTime: now.add(const Duration(minutes: 10)),
    );

    // 1 hour
    await notifier.scheduleNotification(
      id: 4,
      title: '1 Hour Notification',
      body: 'This fired after 1 hour!',
      scheduledTime: now.add(const Duration(hours: 1)),
    );

    // Schedule 6 PM and 8 PM
    DateTime sixPm = DateTime(now.year, now.month, now.day, 18, 0);
    DateTime eightPm = DateTime(now.year, now.month, now.day, 20, 0);
    if (sixPm.isBefore(now)) sixPm = sixPm.add(const Duration(days: 1));
    if (eightPm.isBefore(now)) eightPm = eightPm.add(const Duration(days: 1));

    await notifier.scheduleNotification(
      id: 5,
      title: '6 PM Notification',
      body: 'It’s 6 PM!',
      scheduledTime: sixPm,
    );

    await notifier.scheduleNotification(
      id: 6,
      title: '8 PM Notification',
      body: 'It’s 8 PM!',
      scheduledTime: eightPm,
    );

    debugPrint('✅ All notifications scheduled successfully!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Notifications Tester')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.notifications_active),
              label: const Text('Show Instant Notification'),
              onPressed: () {
                NotificationService().showInstantNotification(
                  title: 'Hello!',
                  body: 'This works even in background!',
                  payload: 'demo_payload',
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.schedule),
              label: const Text('Schedule All Notifications'),
              onPressed: _scheduleAll,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever),
              label: const Text('Cancel All Notifications'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await NotificationService().cancelAll();
              },
            ),
          ],
        ),
      ),
    );
  }
}
