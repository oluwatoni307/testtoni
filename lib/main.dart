import 'package:flutter/material.dart';
import 'my_notification_package.dart';

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
        appBar: AppBar(title: const Text('Notifications')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () {
                  NotificationService().showInstantNotification(
                    title: 'Hello!',
                    body: 'This works even in background!',
                    payload: 'demo_payload',
                  );
                },
                child: const Text('Show Instant Notification'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
