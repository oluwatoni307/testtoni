// pubspec.yaml
// dependencies:
//   workmanager: ^0.8.0
//   flutter_local_notifications: ^x.y.z   // whichever version you're using

import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const myPeriodicTask = "myPeriodicTask";

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// This must be a top-level or static function
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == myPeriodicTask) {
      // Initialize notifications in background
      const AndroidInitializationSettings androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings =
          InitializationSettings(android: androidInit);
      await flutterLocalNotificationsPlugin.initialize(initSettings);

      // Show notification
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'periodic_channel_id',
        'Periodic Notifications',
        channelDescription: 'Channel for periodic 30-min notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
      const NotificationDetails notificationDetails =
          NotificationDetails(android: androidDetails);

      await flutterLocalNotificationsPlugin.show(
        0,
        "Reminder",
        "This is your 30-minute periodic notification",
        notificationDetails,
      );
    }

    // Return true when the background task is successful
    return Future.value(true);
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode:
        false, // set to true only for debugging; background tasks behave differently in release
  );

  // Register the periodic task
  Workmanager().registerPeriodicTask(
    "periodicTaskUniqueName",
    myPeriodicTask,
    frequency: const Duration(minutes: 30),
    // You can set constraints if needed
    constraints: Constraints(
      networkType: NetworkType.not_required,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '30-min Notification Demo',
      home: Scaffold(
        appBar: AppBar(title: const Text('Periodic Notification')),
        body: const Center(child: Text('Notifications every 30 minutes.')),
      ),
    );
  }
}
