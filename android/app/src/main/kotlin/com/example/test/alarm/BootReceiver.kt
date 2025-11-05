package com.example.test.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.example.test.utils.Logger

/**
 * Reschedules alarms after device reboot.
 * This ensures notifications survive system restarts.
 */
class BootReceiver : BroadcastReceiver() {
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action in arrayOf(
                Intent.ACTION_BOOT_COMPLETED,
                Intent.ACTION_LOCKED_BOOT_COMPLETED,
                Intent.ACTION_MY_PACKAGE_REPLACED
            )
        ) {
            Logger.logBoot()
            
            try {
                // Get all active alarms from storage
                val storage = AlarmStorage(context)
                val activeAlarms = storage.getActiveAlarms()
                
                Logger.i("Found ${activeAlarms.size} active alarms to reschedule")
                
                // Reschedule each one
                val scheduler = AlarmScheduler(context)
                var successCount = 0
                
                activeAlarms.forEach { alarm ->
                    val success = scheduler.scheduleExactAlarm(
                        alarm.id,
                        alarm.title,
                        alarm.body,
                        alarm.timestamp,
                        alarm.payload
                    )
                    if (success) successCount++
                }
                
                Logger.success("Rescheduled $successCount/${activeAlarms.size} alarms after boot")
                
            } catch (e: Exception) {
                Logger.e("Error in BootReceiver", e)
            }
        }
    }
}