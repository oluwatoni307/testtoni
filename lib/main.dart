import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'dailly_sync.dart';
import 'manager.dart';
import 'model.dart';
import 'permission_manager.dart';

/* ==========================  MAIN  ========================== */
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /* ----  singletons  ---- */
  await NotificationManager().initialize(
    onNotificationTap: (p) => print('📬 TAPPED notification payload: $p'),
  );
  await SyncManager().initialize();

  /* ----  WorkManager callback (top-level)  ---- */
  @pragma('vm:entry-point')
  void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      await NotificationManager().initialize(); // cold-start isolate
      if (task == 'api_daily_sync') {
        final sync = ApiDailySync(
          apiUrl: 'https://jsonplaceholder.typicode.com/posts',
          fetchReminders: () async => _fakeApi(),
        );
        final r = await sync.sync();
        print('📡 BG API sync => $r');
        return Future.value(r.success);
      }
      if (task == 'user_daily_sync') {
        final r = await UserDailySync().sync();
        print('👤 BG USER sync => $r');
        return Future.value(r.success);
      }
      return Future.value(false);
    });
  }

  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  runApp(const MyApp());
}

/* ==========================  FAKE API  ========================== */
Future<List<NotificationItem>> _fakeApi() async {
  await Future.delayed(const Duration(seconds: 1));
  final now = DateTime.now().add(const Duration(minutes: 2));
  return [
    NotificationItem(
      id: 'api_${now.millisecond}',
      title: 'API pill ${now.minute}',
      body: 'Fetched from server',
      source: NotificationSource.api,
      oneTimeDate: now,
      createdAt: DateTime.now(),
    ),
  ];
}

/* ==========================  UI  ========================== */
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Notification Lab')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _Btn('1. Check permissions', _checkPerms),
              _Btn('2. Request missing', _requestPerms),
              _Btn('3. Add user reminder', _userRem),
              _Btn('4. Trigger API sync', _apiSync),
              _Btn('5. Schedule BG jobs', _bgJobs),
              _Btn('🔥 6. Stress-test 5× alarms (2 h)', _stressTest),
              _Btn('7. Print diagnostics', _diagnose),
            ],
          ),
        ),
      ),
    );
  }
}

/* --------------------  reusable button  -------------------- */
class _Btn extends StatelessWidget {
  final String label;
  final VoidCallback fn;
  const _Btn(this.label, this.fn);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: ElevatedButton(onPressed: fn, child: Text(label)),
  );
}

/* --------------------  action helpers  -------------------- */
Future<void> _checkPerms() async =>
    print('PERMISSIONS => ${await PermissionManager().checkAllPermissions()}');

Future<void> _requestPerms() async => print(
  'AFTER REQUEST => ${await PermissionManager().requestAllPermissions()}',
);

Future<void> _userRem() async {
  final item = NotificationItem(
    id: 'user_${DateTime.now().millisecond}',
    title: 'User pill',
    body: 'Take with water',
    source: NotificationSource.user,
    recurringTime: const TimeOfDay(hour: 8, minute: 0),
    endDate: DateTime.now().add(const Duration(days: 3)),
    createdAt: DateTime.now(),
  );
  await NotificationManager().schedule(item);
  print('USER recurring reminder scheduled');
}

Future<void> _apiSync() async {
  final r = await ApiDailySync(
    apiUrl: 'dummy',
    fetchReminders: _fakeApi,
  ).sync();
  print('API sync result => $r');
}

Future<void> _bgJobs() async {
  await SyncManager().setupUserSync();
  await SyncManager().setupApiSync(apiUrl: 'dummy', fetchReminders: _fakeApi);
  print('BG jobs registered (check logcat WM-)');
}

Future<void> _stressTest() async {
  final now = DateTime.now();
  const count = 5;
  const step = Duration(minutes: 24); // 24 * 5 = 120 min window
  for (int i = 0; i < count; i++) {
    final fireAt = now.add(step * (i + 1));
    final item = NotificationItem(
      id: 'stress_${i}_${now.millisecond}', // unique
      title: 'Stress pill #${i + 1}',
      body:
          'Alarm ${i + 1}/$count  –  ${fireAt.hour}:${fireAt.minute.toString().padLeft(2, '0')}',
      source: NotificationSource.user,
      oneTimeDate: fireAt,
      createdAt: now,
    );
    await NotificationManager().schedule(item);
  }
  final last = now.add(step * count);
  print('SCHEDULED $count exact alarms, last at $last');
}

Future<void> _diagnose() async {
  await NotificationManager().printDiagnostics();
  await PermissionManager().printDiagnostics();
}
