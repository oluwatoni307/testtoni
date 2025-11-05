package com.example.test.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import com.example.test.notification.NotificationHelper
import com.example.test.utils.Logger

/**
 * Receives alarm broadcasts and shows notifications.
 * This runs even if the app is completely killed.
 */
class AlarmReceiver : BroadcastReceiver() {
    
    companion object {
        const val EXTRA_ALARM_ID = "alarm_id"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        // Acquire wake lock to ensure we complete before device sleeps
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "NativeAlarm::AlarmWakeLock"
        )
        
        try {
            wakeLock.acquire(60000) // 60 second max
            
            val alarmId = intent.getIntExtra(EXTRA_ALARM_ID, -1)
            
            if (alarmId == -1) {
                Logger.e("Invalid alarm ID received")
                return
            }
            
            Logger.i("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            Logger.i("  ALARM TRIGGERED: ID=$alarmId")
            Logger.i("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            
            // Get alarm data from storage
            val storage = AlarmStorage(context)
            val alarmData = storage.getAlarm(alarmId)
            
            if (alarmData == null) {
                Logger.w("Alarm data not found for ID=$alarmId")
                // Show generic notification anyway
                NotificationHelper(context).showNotification(
                    alarmId,
                    "Reminder",
                    "You have a scheduled reminder"
                )
                return
            }
            
            // Show notification
            NotificationHelper(context).showNotification(
                alarmData.id,
                alarmData.title,
                alarmData.body,
                alarmData.payload
            )
            
            // Clean up this alarm from storage (one-time alarms)
            storage.deleteAlarm(alarmId)
            
            Logger.success("Alarm processed successfully: ID=$alarmId")
            
        } catch (e: Exception) {
            Logger.e("Error in AlarmReceiver", e)
        } finally {
            if (wakeLock.isHeld) {
                wakeLock.release()
            }
        }
    }
}