package com.example.test

import com.example.test.alarm.AlarmReceiver  // ✅ Import your receiver

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.test/alarm"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleAlarm" -> {
                        val title = call.argument<String>("title") ?: "Reminder"
                        val message = call.argument<String>("message") ?: "It's time!"
                        val delayMinutes = call.argument<Int>("delayMinutes") ?: 1

                        // Calculate trigger time
                        val triggerAtMillis = System.currentTimeMillis() + delayMinutes * 60 * 1000

                        // Schedule the alarm using our Kotlin companion method
                        AlarmReceiver.scheduleAlarm(
                            applicationContext,
                            triggerAtMillis,
                            title,
                            message
                        )

                        result.success("Alarm set for +$delayMinutes minutes")
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
