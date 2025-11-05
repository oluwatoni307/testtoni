package com.example.test.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.example.test.utils.Logger
import java.util.Calendar

class NativeAlarmManager(private val context: Context) {
    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val storage = AlarmStorage(context)

    fun scheduleAlarm(id: Int, title: String, body: String, timestamp: Long, payload: String? = null) {
        try {
            Logger.i("ℹ️ ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            Logger.i("ℹ️ ┃ SCHEDULING ALARM")
            Logger.i("ℹ️ ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            Logger.i("ℹ️ ┃ ID: $id")
            Logger.i("ℹ️ ┃ Time: ${Calendar.getInstance().apply { timeInMillis = timestamp }.time}")
            Logger.i("ℹ️ ┃ Title: $title")
            Logger.i("ℹ️ ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            // Save alarm data (use the top-level AlarmData model)
            storage.saveAlarm(
                AlarmData(
                    id = id,
                    title = title,
                    body = body,
                    timestamp = timestamp,
                    payload = payload
                )
            )
            Logger.d("📘 Alarm saved: ID=$id, Total=${storage.getAllAlarms().size}")

            // Create intent
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                putExtra(AlarmReceiver.EXTRA_ALARM_ID, id)
            }

            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val pendingIntent = PendingIntent.getBroadcast(context, id, intent, flags)

            // Schedule with exact timing
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Logger.d("📘 Using setExactAndAllowWhileIdle (Android 6.0+)")
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    timestamp,
                    pendingIntent
                )
            } else {
                Logger.d("📘 Using setExact (pre-Android 6.0)")
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    timestamp,
                    pendingIntent
                )
            }

            Logger.success("✅ Alarm scheduled successfully: ID=$id")
        } catch (e: Exception) {
            Logger.e("❌ Failed to schedule alarm: ID=$id", e)
            throw e
        }
    }

    fun cancelAlarm(id: Int) {
        try {
            // Cancel alarm
            val intent = Intent(context, AlarmReceiver::class.java)
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_NO_CREATE
            }
            val pendingIntent = PendingIntent.getBroadcast(context, id, intent, flags)
            
            pendingIntent?.let {
                alarmManager.cancel(it)
                it.cancel()
            }

            // Delete from storage
            storage.deleteAlarm(id)
            Logger.d("📘 Alarm deleted: ID=$id, Remaining=${storage.getAllAlarms().size}")
            Logger.i("ℹ️ 🗑️ ALARM CANCELLED: ID=$id")
        } catch (e: Exception) {
            Logger.e("Failed to cancel alarm: ID=$id", e)
            throw e
        }
    }

    fun getScheduledAlarms(): List<AlarmData> {
        return storage.getAllAlarms()
    }
}