package com.example.test

import com.example.test.alarm.AlarmReceiver  // ✅ correct import
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.os.SystemClock
import java.util.*

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.test/alarm"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleAlarm" -> {
                        val title = call.argument<String>("title") ?: "Reminder"
                        val message = call.argument<String>("message") ?: "Time to check!"
                        val delayMinutes = call.argument<Int>("delayMinutes") ?: 1

                        val triggerAtMillis = System.currentTimeMillis() + delayMinutes * 60 * 1000

                        // ✅ Create instance and schedule
                        val receiver = AlarmReceiver()
                        receiver.scheduleAlarm(applicationContext, triggerAtMillis, title, message)

                        result.success("Alarm set for +$delayMinutes minutes")
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
