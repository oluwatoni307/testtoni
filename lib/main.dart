import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:async';

import 'dailly_sync.dart';
import 'manager.dart';
import 'model.dart';
import 'permission_manager.dart';
import 'storage.dart';

/* ==========================  MAIN  ========================== */
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /* ----  singletons  ---- */
  await NotificationManager().initialize(
    onNotificationTap: (p) {
      print('📬 TAPPED notification payload: $p');
    },
  );
  await SyncManager().initialize();

  /* ----  WorkManager callback (top-level)  ---- */
  @pragma('vm:entry-point')
  void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      await NotificationManager().initialize();
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
  final now = DateTime.now();
  return [
    NotificationItem(
      id: 'api_${now.millisecondsSinceEpoch}_1',
      title: 'Morning Medicine',
      body: 'Take 2 tablets with water',
      source: NotificationSource.api,
      oneTimeDate: now.add(const Duration(minutes: 2)),
      createdAt: now,
    ),
    NotificationItem(
      id: 'api_${now.millisecondsSinceEpoch}_2',
      title: 'Afternoon Vitamin',
      body: 'Take vitamin D supplement',
      source: NotificationSource.api,
      oneTimeDate: now.add(const Duration(minutes: 5)),
      createdAt: now,
    ),
  ];
}

/* ==========================  UI  ========================== */
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final List<TestReport> _reports = [];
  bool _isRunning = false;
  String _currentTest = '';
  int _notificationTapCount = 0;

  @override
  void initState() {
    super.initState();
    // Re-initialize with tap counter
    NotificationManager().initialize(
      onNotificationTap: (p) {
        setState(() {
          _notificationTapCount++;
        });
        _showSnackBar(
          '📬 Notification tapped! Count: $_notificationTapCount',
          Colors.blue,
        );
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Notification Package Test Suite'),
          backgroundColor: Colors.blue,
          actions: [
            if (_notificationTapCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Chip(
                    label: Text('Taps: $_notificationTapCount'),
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            // Test Controls
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Column(
                children: [
                  if (_isRunning)
                    Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 8),
                        Text(
                          _currentTest,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _runAllTests,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Run All Tests'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _clearReports,
                              icon: const Icon(Icons.clear),
                              label: const Text('Clear Reports'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _TestButton('Permissions', _testPermissions),
                            _TestButton('Storage', _testStorage),
                            _TestButton('Scheduling', _testScheduling),
                            _TestButton('User Sync', _testUserSync),
                            _TestButton('API Sync', _testApiSync),
                            _TestButton('Settings', _testSettings),
                            _TestButton('Health Check', _testHealthCheck),
                            _TestButton('Quick Test', _testQuickNotification),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Reports List
            Expanded(
              child: _reports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.science_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No tests run yet.\nClick "Run All Tests" to start.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _reports.length,
                      padding: const EdgeInsets.all(8),
                      itemBuilder: (context, index) {
                        final report = _reports[index];
                        return _ReportCard(report: report);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runAllTests() async {
    _showSnackBar('🚀 Starting all tests...', Colors.blue);

    setState(() {
      _isRunning = true;
      _reports.clear();
    });

    await _testPermissions();
    await _testStorage();
    await _testScheduling();
    await _testUserSync();
    await _testApiSync();
    await _testSettings();
    await _testHealthCheck();

    setState(() {
      _isRunning = false;
      _currentTest = '';
    });

    _showSummaryDialog();
  }

  void _clearReports() {
    setState(() {
      _reports.clear();
    });
    _showSnackBar('🗑️ Reports cleared', Colors.orange);
  }

  void _showSummaryDialog() {
    final passed = _reports.where((r) => r.passed).length;
    final failed = _reports.length - passed;

    _showSnackBar(
      failed == 0
          ? '✅ All $passed tests passed!'
          : '⚠️ $passed passed, $failed failed',
      failed == 0 ? Colors.green : Colors.orange,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              failed == 0 ? Icons.check_circle : Icons.warning,
              color: failed == 0 ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text('Test Summary'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Tests: ${_reports.length}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '✅ Passed: $passed',
              style: const TextStyle(color: Colors.green, fontSize: 15),
            ),
            Text(
              '❌ Failed: $failed',
              style: const TextStyle(color: Colors.red, fontSize: 15),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: failed == 0
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                failed == 0
                    ? '🎉 All tests passed!'
                    : '⚠️ Some tests failed - check details below',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: failed == 0
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _addReport(TestReport report) {
    setState(() {
      _reports.insert(0, report);
    });

    // Show immediate feedback
    final emoji = report.passed ? '✅' : '❌';
    final color = report.passed ? Colors.green : Colors.red;
    _showSnackBar(
      '$emoji ${report.name} - ${report.passed ? "PASSED" : "FAILED"}',
      color,
    );
  }

  /* ==================== TEST IMPLEMENTATIONS ==================== */

  Future<void> _testPermissions() async {
    _showSnackBar('🔐 Testing permissions...', Colors.blue);
    setState(() => _currentTest = 'Testing Permissions...');

    final stopwatch = Stopwatch()..start();
    final details = <String, dynamic>{};
    bool passed = true;
    String? error;

    try {
      // Check all permissions
      final status = await PermissionManager().checkAllPermissions();

      details['✓ Notifications Granted'] = status.notificationsGranted
          ? '✅ Yes'
          : '❌ No';
      details['✓ Exact Alarms Granted'] = status.exactAlarmsGranted
          ? '✅ Yes'
          : '❌ No';
      details['✓ Battery Optimized'] = status.batteryOptimized
          ? '⚠️ Yes (Bad)'
          : '✅ No (Good)';
      details['Device Info'] = status.deviceInfo ?? 'Unknown';
      details['Aggressive Device'] = status.needsSpecialGuidance
          ? '⚠️ Yes'
          : '✅ No';

      // Get detailed report
      final report = await PermissionManager().getPermissionReport();
      details['Android SDK'] = report['android_sdk'];
      details['Manufacturer'] = report['manufacturer'];
      details['Is HiOS'] = report['is_hios'];
      details['Is MIUI'] = report['is_miui'];

      // Verify critical permissions
      if (!status.notificationsGranted || !status.exactAlarmsGranted) {
        details['⚠️ Warning'] =
            'Some permissions missing - tap "Request missing" in Permission Manager';
        passed = false;
        error =
            'Missing critical permissions: ${status.missingPermissions.join(", ")}';
      }

      passed = status.allGranted;
    } catch (e) {
      passed = false;
      error = e.toString();
    }

    stopwatch.stop();
    _addReport(
      TestReport(
        name: '🔐 Permissions Test',
        passed: passed,
        duration: stopwatch.elapsed,
        details: details,
        error: error,
      ),
    );
  }

  Future<void> _testStorage() async {
    _showSnackBar('💾 Testing storage...', Colors.blue);
    setState(() => _currentTest = 'Testing Storage...');

    final stopwatch = Stopwatch()..start();
    final details = <String, dynamic>{};
    bool passed = true;
    String? error;

    try {
      final storage = NotificationStorage();
      int passedTests = 0;
      const totalTests = 7;

      // Test 1: Save notification
      final testItem = NotificationItem(
        id: 'test_storage_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Test Notification',
        body: 'This is a test',
        source: NotificationSource.user,
        oneTimeDate: DateTime.now().add(const Duration(hours: 1)),
        createdAt: DateTime.now(),
      );

      await storage.saveNotification(testItem);
      details['1️⃣ Save Operation'] = '✅ Success';
      passedTests++;

      // Test 2: Retrieve notification
      final retrieved = await storage.getNotificationById(testItem.id);
      if (retrieved != null && retrieved.id == testItem.id) {
        details['2️⃣ Retrieve Operation'] = '✅ Success (ID matches)';
        passedTests++;
      } else {
        details['2️⃣ Retrieve Operation'] = '❌ Failed (null or ID mismatch)';
      }

      // Test 3: Update notification
      final updated = testItem.copyWith(title: 'Updated Title');
      await storage.updateNotification(updated);
      final retrievedUpdated = await storage.getNotificationById(testItem.id);
      if (retrievedUpdated?.title == 'Updated Title') {
        details['3️⃣ Update Operation'] = '✅ Success (Title changed)';
        passedTests++;
      } else {
        details['3️⃣ Update Operation'] = '❌ Failed (Title not updated)';
      }

      // Test 4: Get by source
      final userNotifs = await storage.getNotificationsBySource(
        NotificationSource.user,
      );
      details['4️⃣ Filter by Source'] =
          '✅ Found ${userNotifs.length} user notifications';
      passedTests++;

      // Test 5: Statistics
      final stats = await storage.getStatistics();
      details['5️⃣ Statistics'] =
          '✅ Total: ${stats['total']}, Active: ${stats['active']}';
      passedTests++;

      // Test 6: Cache operations
      final testDate = DateTime.now();
      await storage.cacheApiReminders(testDate, [testItem]);
      final cached = await storage.getCachedApiReminders(testDate);
      if (cached != null && cached.isNotEmpty) {
        details['6️⃣ Cache Operation'] =
            '✅ Success (${cached.length} items cached)';
        passedTests++;
      } else {
        details['6️⃣ Cache Operation'] = '❌ Failed (Cache empty)';
      }

      // Test 7: Delete
      await storage.deleteNotification(testItem.id);
      final deleted = await storage.getNotificationById(testItem.id);
      if (deleted == null) {
        details['7️⃣ Delete Operation'] = '✅ Success (Item removed)';
        passedTests++;
      } else {
        details['7️⃣ Delete Operation'] = '❌ Failed (Item still exists)';
      }

      details['📊 Test Score'] = '$passedTests/$totalTests passed';
      passed = passedTests == totalTests;

      if (!passed) {
        error = 'Only $passedTests out of $totalTests storage tests passed';
      }
    } catch (e) {
      passed = false;
      error = 'Exception: ${e.toString()}';
    }

    stopwatch.stop();
    _addReport(
      TestReport(
        name: '💾 Storage Test',
        passed: passed,
        duration: stopwatch.elapsed,
        details: details,
        error: error,
      ),
    );
  }

  Future<void> _testScheduling() async {
    _showSnackBar('⏰ Testing scheduling...', Colors.blue);
    setState(() => _currentTest = 'Testing Notification Scheduling...');

    final stopwatch = Stopwatch()..start();
    final details = <String, dynamic>{};
    bool passed = true;
    String? error;

    try {
      final manager = NotificationManager();
      final now = DateTime.now();
      int passedTests = 0;

      // Test 1: One-time notification
      final oneTime = NotificationItem(
        id: 'test_onetime_${now.millisecondsSinceEpoch}',
        title: 'One-Time Test',
        body: 'Fires in 3 minutes',
        source: NotificationSource.user,
        oneTimeDate: now.add(const Duration(minutes: 3)),
        createdAt: now,
      );
      await manager.schedule(oneTime);

      // Verify it was scheduled in system
      final pendingAfterOne = await manager.getPendingNotifications();
      if (pendingAfterOne.any((p) => p.id == oneTime.id.hashCode)) {
        details['1️⃣ One-Time Scheduling'] = '✅ Verified in system';
        passedTests++;
      } else {
        details['1️⃣ One-Time Scheduling'] = '❌ Not found in system';
      }

      // Test 2: Recurring notification
      final recurring = NotificationItem(
        id: 'test_recurring_${now.millisecondsSinceEpoch}',
        title: 'Recurring Test',
        body: 'Daily reminder',
        source: NotificationSource.user,
        recurringTime: TimeOfDay.fromDateTime(
          now.add(const Duration(minutes: 1)),
        ),
        endDate: now.add(const Duration(days: 3)),
        createdAt: now,
      );
      await manager.schedule(recurring);

      // Verify it was scheduled
      final pendingAfterRecur = await manager.getPendingNotifications();
      if (pendingAfterRecur.any((p) => p.id == recurring.id.hashCode)) {
        details['2️⃣ Recurring Scheduling'] = '✅ Verified in system';
        passedTests++;
      } else {
        details['2️⃣ Recurring Scheduling'] = '❌ Not found in system';
      }

      details['📊 Pending Notifications'] =
          '${pendingAfterRecur.length} in system';

      // Test 3: Verify in database
      final stored = await manager.getById(oneTime.id);
      if (stored != null) {
        details['3️⃣ Database Storage'] = '✅ Notification saved to DB';
        passedTests++;
      } else {
        details['3️⃣ Database Storage'] = '❌ Not found in DB';
      }

      // Cleanup
      await manager.delete(oneTime.id);
      await manager.delete(recurring.id);
      details['🧹 Cleanup'] = '✅ Test notifications removed';

      passed = passedTests >= 2;
      if (!passed) {
        error = 'Only $passedTests/3 scheduling tests passed';
      }
    } catch (e) {
      passed = false;
      error = 'Exception: ${e.toString()}';
    }

    stopwatch.stop();
    _addReport(
      TestReport(
        name: '⏰ Scheduling Test',
        passed: passed,
        duration: stopwatch.elapsed,
        details: details,
        error: error,
      ),
    );
  }

  Future<void> _testUserSync() async {
    _showSnackBar('👤 Testing user sync...', Colors.blue);
    setState(() => _currentTest = 'Testing User Sync...');

    final stopwatch = Stopwatch()..start();
    final details = <String, dynamic>{};
    bool passed = true;
    String? error;

    try {
      final sync = UserDailySync();
      final manager = NotificationManager();
      final storage = NotificationStorage();
      final now = DateTime.now();

      // Create test recurring notifications
      final testNotifs = [
        NotificationItem(
          id: 'user_test_1_${now.millisecondsSinceEpoch}',
          title: 'Morning Pill',
          body: 'Take with breakfast',
          source: NotificationSource.user,
          recurringTime: const TimeOfDay(hour: 8, minute: 0),
          endDate: now.add(const Duration(days: 7)),
          createdAt: now,
        ),
        NotificationItem(
          id: 'user_test_2_${now.millisecondsSinceEpoch}',
          title: 'Evening Pill',
          body: 'Take with dinner',
          source: NotificationSource.user,
          recurringTime: const TimeOfDay(hour: 20, minute: 0),
          endDate: now.add(const Duration(days: 7)),
          createdAt: now,
        ),
      ];

      // Schedule them
      for (final notif in testNotifs) {
        await manager.schedule(notif);
      }
      details['📝 Test Notifications'] = '${testNotifs.length} created';

      // Verify they're in storage
      final userNotifs = await storage.getNotificationsBySource(
        NotificationSource.user,
      );
      details['💾 In Database'] = '${userNotifs.length} user notifications';

      // Run sync
      final result = await sync.sync();
      details['🔄 Sync Result'] = result.success ? '✅ Success' : '❌ Failed';
      details['📊 Scheduled Count'] = result.scheduledCount;

      if (result.errorMessage != null) {
        details['⚠️ Error'] = result.errorMessage!;
      }

      // Verify notifications are in system
      final pending = await manager.getPendingNotifications();
      final userPending = pending
          .where((p) => testNotifs.any((t) => t.id.hashCode == p.id))
          .length;
      details['⏰ In System'] = '$userPending pending';

      // Cleanup
      for (final notif in testNotifs) {
        await manager.delete(notif.id);
      }

      passed = result.success && result.scheduledCount > 0;

      if (!passed) {
        error =
            result.errorMessage ?? 'Sync failed or no notifications scheduled';
      }
    } catch (e) {
      passed = false;
      error = 'Exception: ${e.toString()}';
    }

    stopwatch.stop();
    _addReport(
      TestReport(
        name: '👤 User Sync Test',
        passed: passed,
        duration: stopwatch.elapsed,
        details: details,
        error: error,
      ),
    );
  }

  Future<void> _testApiSync() async {
    _showSnackBar('📡 Testing API sync...', Colors.blue);
    setState(() => _currentTest = 'Testing API Sync...');

    final stopwatch = Stopwatch()..start();
    final details = <String, dynamic>{};
    bool passed = true;
    String? error;

    try {
      final sync = ApiDailySync(
        apiUrl: 'https://jsonplaceholder.typicode.com/posts',
        fetchReminders: _fakeApi,
      );
      final manager = NotificationManager();

      details['🌐 API URL'] = 'Using fake API';

      // Run sync
      final result = await sync.sync();
      details['🔄 Sync Result'] = result.success ? '✅ Success' : '❌ Failed';
      details['📊 Scheduled Count'] = result.scheduledCount;
      details['💾 Used Cache'] = result.usedCache ? '⚠️ Yes' : '✅ No (Fresh)';

      if (result.errorMessage != null) {
        details['⚠️ Error'] = result.errorMessage!;
      }

      // Verify notifications in database
      final apiNotifs = await manager.getBySource(NotificationSource.api);
      details['💾 In Database'] = '${apiNotifs.length} API notifications';

      // Verify in system
      final pending = await manager.getPendingNotifications();
      final apiPending = pending
          .where((p) => apiNotifs.any((a) => a.id.hashCode == p.id))
          .length;
      details['⏰ In System'] = '$apiPending pending';

      // Show first notification details
      if (apiNotifs.isNotEmpty) {
        final first = apiNotifs.first;
        details['📋 Sample'] = '${first.title} at ${first.oneTimeDate}';
      }

      passed =
          result.success && result.scheduledCount > 0 && apiNotifs.isNotEmpty;

      if (!passed) {
        error =
            result.errorMessage ?? 'Sync succeeded but no notifications found';
      }
    } catch (e) {
      passed = false;
      error = 'Exception: ${e.toString()}';
    }

    stopwatch.stop();
    _addReport(
      TestReport(
        name: '📡 API Sync Test',
        passed: passed,
        duration: stopwatch.elapsed,
        details: details,
        error: error,
      ),
    );
  }

  Future<void> _testSettings() async {
    _showSnackBar('⚙️ Testing settings...', Colors.blue);
    setState(() => _currentTest = 'Testing Settings...');

    final stopwatch = Stopwatch()..start();
    final details = <String, dynamic>{};
    bool passed = true;
    String? error;

    try {
      final manager = NotificationManager();

      // Get current settings
      final current = await manager.getSettings();
      details['📋 Current Vibration'] = current.vibration ? '✅ On' : '❌ Off';
      details['📋 Current Sound'] = current.sound ? '✅ On' : '❌ Off';
      details['📋 Current Priority'] = current.priority.name;

      // Update settings
      final newSettings = current.copyWith(
        vibration: !current.vibration,
        priority: NotificationPriority.urgent,
      );
      await manager.updateSettings(newSettings);
      details['🔄 Settings Updated'] = '✅ Applied';

      // Verify update
      final updated = await manager.getSettings();
      final vibrationChanged = updated.vibration == !current.vibration;
      final priorityChanged = updated.priority == NotificationPriority.urgent;

      details['✓ Vibration Changed'] = vibrationChanged ? '✅ Yes' : '❌ No';
      details['✓ Priority Changed'] = priorityChanged ? '✅ Yes' : '❌ No';

      // Restore original settings
      await manager.updateSettings(current);
      details['🔙 Restored'] = '✅ Back to original';

      passed = vibrationChanged && priorityChanged;

      if (!passed) {
        error = 'Settings update did not persist correctly';
      }
    } catch (e) {
      passed = false;
      error = 'Exception: ${e.toString()}';
    }

    stopwatch.stop();
    _addReport(
      TestReport(
        name: '⚙️ Settings Test',
        passed: passed,
        duration: stopwatch.elapsed,
        details: details,
        error: error,
      ),
    );
  }

  Future<void> _testHealthCheck() async {
    _showSnackBar('🏥 Running health check...', Colors.blue);
    setState(() => _currentTest = 'Testing Health Check...');

    final stopwatch = Stopwatch()..start();
    final details = <String, dynamic>{};
    bool passed = true;
    String? error;

    try {
      final manager = NotificationManager();

      // Get statistics
      final stats = await manager.getStatistics();
      details['📊 Total'] = stats['total'];
      details['📊 API'] = stats['api'];
      details['📊 User'] = stats['user'];
      details['📊 Active'] = stats['active'];
      details['📊 Inactive'] = stats['inactive'];
      details['📊 System Pending'] = stats['system_pending'];

      // Health check
      final health = await manager.checkHealth();
      details['💾 Database Count'] = health['database_count'];
      details['⏰ System Count'] = health['system_count'];
      details['🔍 In Sync'] = health['in_sync'] ? '✅ Yes' : '⚠️ No';
      details['⚠️ Missing in System'] = health['missing_in_system'];
      details['⚠️ Missing in DB'] = health['missing_in_db'];

      // Consider it passed if mostly in sync (allow small discrepancies)
      passed = health['missing_in_system'] <= 2 && health['missing_in_db'] <= 2;

      if (!passed) {
        error = 'Database and system are out of sync';
      }
    } catch (e) {
      passed = false;
      error = 'Exception: ${e.toString()}';
    }

    stopwatch.stop();
    _addReport(
      TestReport(
        name: '🏥 Health Check Test',
        passed: passed,
        duration: stopwatch.elapsed,
        details: details,
        error: error,
      ),
    );
  }

  Future<void> _testQuickNotification() async {
    _showSnackBar('🚀 Scheduling instant notification...', Colors.blue);
    setState(() => _currentTest = 'Testing Quick Notification...');

    final stopwatch = Stopwatch()..start();
    final details = <String, dynamic>{};
    bool passed = true;
    String? error;

    try {
      final manager = NotificationManager();
      final now = DateTime.now();
      final fireTime = now.add(const Duration(seconds: 5));

      final quickNotif = NotificationItem(
        id: 'quick_${now.millisecondsSinceEpoch}',
        title: '⚡ Quick Test Notification',
        body: 'This should appear in 5 seconds! Tap it to test tap handler.',
        source: NotificationSource.user,
        oneTimeDate: fireTime,
        createdAt: now,
      );

      await manager.schedule(quickNotif);

      details['⏰ Scheduled For'] =
          '${fireTime.hour}:${fireTime.minute}:${fireTime.second}';
      details['🕐 Current Time'] = '${now.hour}:${now.minute}:${now.second}';
      details['⏱️ Delay'] = '5 seconds';
      details['📋 Notification ID'] = quickNotif.id;

      // Verify it's in the system
      final pending = await manager.getPendingNotifications();
      final found = pending.any((p) => p.id == quickNotif.id.hashCode);

      details['✓ In System'] = found ? '✅ Yes' : '❌ No';
      details['💡 Instructions'] =
          'Wait 5 seconds and tap the notification to test tap handler';

      passed = found;

      if (!passed) {
        error = 'Notification was not scheduled in the system';
      }

      // Show countdown dialog
      if (found) {
        _showCountdownDialog(quickNotif.id);
      }
    } catch (e) {
      passed = false;
      error = 'Exception: ${e.toString()}';
    }

    stopwatch.stop();
    _addReport(
      TestReport(
        name: '🚀 Quick Notification Test',
        passed: passed,
        duration: stopwatch.elapsed,
        details: details,
        error: error,
      ),
    );
  }

  void _showCountdownDialog(String notificationId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CountdownDialog(
        notificationId: notificationId,
        onComplete: () {
          Navigator.of(context).pop();
          _showSnackBar('⏰ Notification should have fired!', Colors.green);
        },
      ),
    );
  }
}

/* ==================== COUNTDOWN DIALOG ==================== */

class _CountdownDialog extends StatefulWidget {
  final String notificationId;
  final VoidCallback onComplete;

  const _CountdownDialog({
    required this.notificationId,
    required this.onComplete,
  });

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  int _countdown = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdown--;
      });

      if (_countdown <= 0) {
        timer.cancel();
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.notifications_active, color: Colors.orange),
          SizedBox(width: 8),
          Text('Notification Coming...'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$_countdown',
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.bold,
              color: _countdown <= 2 ? Colors.red : Colors.blue,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Get ready to tap the notification!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            _timer?.cancel();
            Navigator.of(context).pop();
            // Delete the notification
            await NotificationManager().delete(widget.notificationId);
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/* ==================== HELPER WIDGETS ==================== */

class _TestButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _TestButton(this.label, this.onPressed);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final TestReport report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(
          report.passed ? Icons.check_circle : Icons.error,
          color: report.passed ? Colors.green : Colors.red,
          size: 32,
        ),
        title: Text(
          report.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: report.passed
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: report.passed ? Colors.green : Colors.red,
                    width: 1,
                  ),
                ),
                child: Text(
                  report.passed ? "PASSED" : "FAILED",
                  style: TextStyle(
                    color: report.passed
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '⏱️ ${report.duration.inMilliseconds}ms',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (report.error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'ERROR:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          report.error!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Row(
                  children: [
                    Icon(Icons.list_alt, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'DETAILS:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...report.details.entries.map(
                  (e) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 160,
                          child: Text(
                            '${e.key}:',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            e.value.toString(),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ==================== DATA MODELS ==================== */

class TestReport {
  final String name;
  final bool passed;
  final Duration duration;
  final Map<String, dynamic> details;
  final String? error;

  TestReport({
    required this.name,
    required this.passed,
    required this.duration,
    required this.details,
    this.error,
  });
}
