
package com.example.test.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.example.test.utils.Logger

/**
 * Core alarm scheduling logic using Android AlarmManager.
 * This is the most reliable way to schedule exact-time notifications.
 */
class AlarmScheduler(private val context: Context) {
    
    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val storage = AlarmStorage(context)
    
    /**
     * Schedule an exact alarm
     * 
     * @param id Notification ID (must be positive)
     * @param title Notification title
     * @param body Notification body
     * @param triggerTimeMillis When to trigger (milliseconds since epoch)
     * @param payload Optional payload for callback
     * @return true if scheduled successfully
     */
    fun scheduleExactAlarm(
        id: Int,
        title: String,
        body: String,
        triggerTimeMillis: Long,
        payload: String? = null
    ): Boolean {
        try {
            Logger.logSchedule(id, triggerTimeMillis, title)
            
            // Validate inputs
            if (id <= 0) {
                Logger.e("Invalid ID: $id (must be positive)")
                return false
            }
            
            val now = System.currentTimeMillis()
            if (triggerTimeMillis <= now) {
                Logger.w("Trigger time is in the past, adjusting to 30 seconds from now")
                return scheduleExactAlarm(id, title, body, now + 30000, payload)
            }
            
            // Check permission for Android 12+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (!alarmManager.canScheduleExactAlarms()) {
                    Logger.e("Exact alarm permission not granted")
                    return false
                }
            }
            
            // Save alarm data to storage first (use top-level AlarmData model)
            storage.saveAlarm(
                AlarmData(
                    id = id,
                    title = title,
                    body = body,
                    timestamp = triggerTimeMillis,
                    payload = payload
                )
            )
            
            // Create intent for AlarmReceiver
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                putExtra(AlarmReceiver.EXTRA_ALARM_ID, id)
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Schedule alarm using the most reliable method for this Android version
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    // Android 6.0+ (API 23+): Use setExactAndAllowWhileIdle
                    // This bypasses Doze mode and battery optimization
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerTimeMillis,
                        pendingIntent
                    )
                    Logger.d("Using setExactAndAllowWhileIdle (Android 6.0+)")
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT -> {
                    // Android 4.4+ (API 19+): Use setExact
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        triggerTimeMillis,
                        pendingIntent
                    )
                    Logger.d("Using setExact (Android 4.4+)")
                }
                else -> {
                    // Android 4.3 and below: Use set
                    alarmManager.set(
                        AlarmManager.RTC_WAKEUP,
                        triggerTimeMillis,
                        pendingIntent
                    )
                    Logger.d("Using set (Android 4.3-)")
                }
            }
            
            Logger.success("Alarm scheduled successfully: ID=$id")
            return true
            
        } catch (e: SecurityException) {
            Logger.e("Permission denied for exact alarms", e)
            return false
        } catch (e: Exception) {
            Logger.e("Failed to schedule alarm: ID=$id", e)
            return false
        }
    }
    
    /**
     * Cancel an alarm
     */
    fun cancelAlarm(id: Int): Boolean {
        try {
            val intent = Intent(context, AlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            alarmManager.cancel(pendingIntent)
            storage.deleteAlarm(id)
            
            Logger.logCancel(id)
            return true
            
        } catch (e: Exception) {
            Logger.e("Failed to cancel alarm: ID=$id", e)
            return false
        }
    }
    
    /**
     * Cancel all alarms
     */
    fun cancelAllAlarms(): Boolean {
        try {
            val allAlarms = storage.getAllAlarms()
            allAlarms.forEach { alarm ->
                cancelAlarm(alarm.id)
            }
            
            storage.clearAll()
            Logger.i("All alarms cancelled: ${allAlarms.size} total")
            return true
            
        } catch (e: Exception) {
            Logger.e("Failed to cancel all alarms", e)
            return false
        }
    }
    
    /**
     * Get all scheduled alarms
     */
    fun getAllScheduledAlarms(): List<AlarmData> {
        return storage.getAllAlarms()
    }
    
    /**
     * Check if exact alarm permission is granted (Android 12+)
     */
    fun canScheduleExactAlarms(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true // No permission needed before Android 12
        }
    }
}