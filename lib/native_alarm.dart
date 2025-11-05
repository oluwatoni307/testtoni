// lib/native_alarm_test.dart
//
// Comprehensive test suite for native alarm system

import 'package:flutter/material.dart';
import 'native_alarm_manager.dart';
import 'manager.dart';
import 'model.dart';

class NativeAlarmTestScreen extends StatefulWidget {
  const NativeAlarmTestScreen({super.key});

  @override
  State<NativeAlarmTestScreen> createState() => _NativeAlarmTestScreenState();
}

class _NativeAlarmTestScreenState extends State<NativeAlarmTestScreen> {
  final List<TestResult> _results = [];
  bool _isRunning = false;
  String _currentTest = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Native Alarm Test Suite'),
        backgroundColor: Colors.deepPurple,
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _runAllTests,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Run All Tests'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _testQuick30Seconds,
                        icon: const Icon(Icons.timer),
                        label: const Text('Quick 30s Test'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _checkHealth,
                        icon: const Icon(Icons.health_and_safety),
                        label: const Text('Health Check'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _clearResults,
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Results
          Expanded(
            child: _results.isEmpty
                ? const Center(
                    child: Text(
                      'No tests run yet.\nClick "Run All Tests" to start.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (context, index) {
                      return _ResultCard(result: _results[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _addResult(TestResult result) {
    setState(() {
      _results.insert(0, result);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${result.passed ? "✅" : "❌"} ${result.name}'),
        backgroundColor: result.passed ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearResults() {
    setState(() {
      _results.clear();
    });
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isRunning = true;
      _results.clear();
    });

    await _testPermissionCheck();
    await _testScheduling();
    await _testCancellation();
    await _testMultipleAlarms();
    await _checkHealth();

    setState(() {
      _isRunning = false;
      _currentTest = '';
    });

    _showSummary();
  }

  Future<void> _testPermissionCheck() async {
    setState(() => _currentTest = 'Testing Permissions...');

    final stopwatch = Stopwatch()..start();
    final details = <String, dynamic>{};
    bool passed = true;
    String? error;

    try {
      final canSchedule = await NativeAlarmManager.canScheduleExactAlarms();

      details['Can Schedule Exact Alarms'] = canSchedule ? '✅ YES' : '❌ NO';

      if (!canSchedule) {
        details['Action Required'] = 'Tap "Open Settings" to grant permission';
        passed = false;
        error = 'Exact alarm permission not granted';
      }
    } catch (e) {
      passed = false;
      error = e.toString();
    }

    stopwatch.stop();
    _addResult(
      TestResult(
        name: '🔐 Permission Check',
        passed: passed,
        duration: stopwatch.elapsed,
        details: details,
        error: error,
      ),
    );
  }

  Future<void> _testScheduling() async {
    setState(() => _currentTest = 'Testing Scheduling...');

    final stopwatch = Stopwatch()..start();
    final details = <String, dynamic>{};
    bool passed = true;
    String? error;

    try {
      final now = DateTime.now();
      final scheduleTime = now.add(const Duration(minutes: 2));

      final success = await NativeAlarmManager.scheduleAlarm(
        id: 999001,
        title: 'Test Notification',
        body: 'This is a test notification',
        scheduledTime: scheduleTime,
        payload: 'test_payload',
      );

      details['Schedule Result'] = success ? '✅ Success' : '❌ Failed';
      details['Scheduled Time'] = scheduleTime.toString();

      if (success) {
        // Verify it's in the system
        final alarms = await NativeAlarmManager.getAllScheduledAlarms();
        final found = alarms.any((a) => a.id == 999001);

        details['Verified in System'] = found ? '✅ YES' : '❌ NO';
        details['Total Scheduled'] = '${alarms.length} alarms';

        passed = found;
        if (!found) {
          error = 'Alarm not found in system after scheduling';
        }

        // Clean up
        await NativeAlarmManager.cancelAlarm(999001);
      } else {
        passed = false;
        error = 'Scheduling returned false';
      }
    } catch (e) {
      passed = false;
      error = e.toString();
    }

    stopwatch.stop();
    _addResult(
      TestResult(
        name: '⏰ Scheduling Test',
        passed: passed,
        duration: stopwatch.elapsed,
        details: details,
        error: error,
      ),
    );
  }

  Future<void> _testCancellation() async {
    setState(() => _currentTest = 'Testing Cancellation...');

    final stopwatch = Stopwatch()..start();
    final details = <String, dynamic>{};
    bool passed = true;
    String? error;

    try {
      // Schedule an alarm
      final scheduleSuccess = await NativeAlarmManager.scheduleAlarm(
        id: 999002,
        title: 'Cancel Test',
        body: 'This should be cancelled',
        scheduledTime: DateTime.now().add(const Duration(hours: 1)),
      );

      details['Schedule'] = scheduleSuccess ? '✅ OK' : '❌ Failed';

      if (scheduleSuccess) {
        // Cancel it
        final cancelSuccess = await NativeAlarmManager.cancelAlarm(999002);
        details['Cancel'] = cancelSuccess ? '✅ OK' : '❌ Failed';

        // Verify it's gone
        final alarms = await NativeAlarmManager.getAllScheduledAlarms();
        final stillExists = alarms.any((a) => a.id == 999002);

        details['Verified Removed'] = stillExists
            ? '❌ Still Exists'
            : '✅ Removed';

        passed = scheduleSuccess && cancelSuccess && !stillExists;

        if (stillExists) {
          error = 'Alarm still exists after cancellation';
        }
      } else {
        passed = false;
        error = 'Could not schedule test alarm';
      }
    } catch (e) {
      passed = false;
      error = e.toString();
    }

    stopwatch.stop();
    _addResult(
      TestResult(
        name: '🗑️ Cancellation Test',
        passed: passed,
        duration: stopwatch.elapsed,
        details: details,
        error: error,
      ),
    );
  }

  Future<void> _testMultipleAlarms() async {
    setState(() => _currentTest = 'Testing Multiple Alarms...');

    final stopwatch = Stopwatch()..start();
    final details = <String, dynamic>{};
    bool passed = true;
    String? error;

    try {
      final count = 5;
      final now = DateTime.now();
      int successCount = 0;

      // Schedule multiple alarms
      for (int i = 0; i < count; i++) {
        final success = await NativeAlarmManager.scheduleAlarm(
          id: 999100 + i,
          title: 'Test Alarm $i',
          body: 'Test alarm number $i',
          scheduledTime: now.add(Duration(minutes: 10 + i)),
        );

        if (success) successCount++;
      }

      details['Scheduled'] = '$successCount/$count';

      // Verify all are in system
      final alarms = await NativeAlarmManager.getAllScheduledAlarms();
      final testAlarms = alarms
          .where((a) => a.id >= 999100 && a.id < 999100 + count)
          .length;

      details['Verified in System'] = '$testAlarms/$count';

      // Clean up
      for (int i = 0; i < count; i++) {
        await NativeAlarmManager.cancelAlarm(999100 + i);
      }

      passed = successCount == count && testAlarms == count;

      if (!passed) {
        error =
            'Only $successCount/$count scheduled, $testAlarms/$count verified';
      }
    } catch (e) {
      passed = false;
      error = e.toString();
    }

    stopwatch.stop();
    _addResult(
      TestResult(
        name: '📚 Multiple Alarms Test',
        passed: passed,
        duration: stopwatch.elapsed,
        details: details,
        error: error,
      ),
    );
  }

  Future<void> _checkHealth() async {
    setState(() => _currentTest = 'Health Check...');

    final stopwatch = Stopwatch()..start();
    final details = <String, dynamic>{};
    bool passed = true;
    String? error;

    try {
      final health = await NativeAlarmManager.checkHealth();

      details['Can Schedule'] = health.canScheduleExactAlarms
          ? '✅ YES'
          : '❌ NO';
      details['Scheduled Count'] = '${health.scheduledCount} alarms';
      details['System Healthy'] = health.isHealthy ? '✅ YES' : '⚠️ NO';

      if (health.error != null) {
        details['Error'] = health.error!;
      }

      // List scheduled alarms
      if (health.scheduledAlarms.isNotEmpty) {
        details['Next Alarm'] =
            '${health.scheduledAlarms.first.title} at ${health.scheduledAlarms.first.timestamp}';
      }

      passed = health.isHealthy;
      if (!passed) {
        error = health.error ?? 'System not healthy';
      }
    } catch (e) {
      passed = false;
      error = e.toString();
    }

    stopwatch.stop();
    _addResult(
      TestResult(
        name: '🏥 Health Check',
        passed: passed,
        duration: stopwatch.elapsed,
        details: details,
        error: error,
      ),
    );
  }

  Future<void> _testQuick30Seconds() async {
    setState(() {
      _isRunning = true;
      _currentTest = 'Scheduling 30s Test...';
    });

    try {
      final now = DateTime.now();
      final fireTime = now.add(const Duration(seconds: 30));

      final success = await NativeAlarmManager.scheduleAlarm(
        id: 999999,
        title: '⚡ Quick Test - 30 Seconds',
        body: 'If you see this, the native alarm system works!',
        scheduledTime: fireTime,
      );

      if (success) {
        _showCountdownDialog(fireTime);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to schedule alarm'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isRunning = false;
        _currentTest = '';
      });
    }
  }

  void _showCountdownDialog(DateTime fireTime) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CountdownDialog(
        fireTime: fireTime,
        onComplete: () {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⏰ Notification should have appeared!'),
              backgroundColor: Colors.green,
            ),
          );
        },
        onCancel: () async {
          await NativeAlarmManager.cancelAlarm(999999);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showSummary() {
    final passed = _results.where((r) => r.passed).length;
    final failed = _results.length - passed;

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
              'Total Tests: ${_results.length}',
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
            if (failed == 0)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '🎉 All tests passed! Native alarm system is working perfectly!',
                  style: TextStyle(fontWeight: FontWeight.bold),
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
}

class _CountdownDialog extends StatefulWidget {
  final DateTime fireTime;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  const _CountdownDialog({
    required this.fireTime,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  late int _countdown;

  @override
  void initState() {
    super.initState();
    _countdown = widget.fireTime.difference(DateTime.now()).inSeconds;
    _startCountdown();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _countdown = widget.fireTime.difference(DateTime.now()).inSeconds;
        });

        if (_countdown <= 0) {
          widget.onComplete();
        } else {
          _startCountdown();
        }
      }
    });
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
              color: _countdown <= 5 ? Colors.red : Colors.blue,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Get ready! The notification will appear soon.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: 1.0 - (_countdown / 30.0)),
        ],
      ),
      actions: [
        TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final TestResult result;

  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(
          result.passed ? Icons.check_circle : Icons.error,
          color: result.passed ? Colors.green : Colors.red,
          size: 32,
        ),
        title: Text(
          result.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          '${result.passed ? "PASSED" : "FAILED"} • ${result.duration.inMilliseconds}ms',
          style: TextStyle(
            color: result.passed ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
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
                if (result.error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      'ERROR: ${result.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                ...result.details.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 150,
                          child: Text(
                            '${e.key}:',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(child: Text(e.value.toString())),
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

class TestResult {
  final String name;
  final bool passed;
  final Duration duration;
  final Map<String, dynamic> details;
  final String? error;

  TestResult({
    required this.name,
    required this.passed,
    required this.duration,
    required this.details,
    this.error,
  });
}
