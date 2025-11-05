package com.example.test

import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.test.alarm.AlarmScheduler
import com.example.test.utils.Logger

class MainActivity: FlutterActivity() {
    
    private val CHANNEL = "com.example.test/native_alarms"
    private lateinit var alarmScheduler: AlarmScheduler
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize alarm scheduler
        alarmScheduler = AlarmScheduler(this)
        
        Logger.i("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        Logger.i("  NATIVE ALARM SYSTEM INITIALIZED")
        Logger.i("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // Set up MethodChannel for Flutter communication
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleAlarm" -> handleScheduleAlarm(call.arguments, result)
                    "cancelAlarm" -> handleCancelAlarm(call.arguments, result)
                    "cancelAllAlarms" -> handleCancelAllAlarms(result)
                    "getAllScheduledAlarms" -> handleGetAllScheduledAlarms(result)
                    "showTestNotification" -> handleShowTestNotification(call.arguments, result)
                    "canScheduleExactAlarms" -> handleCanScheduleExactAlarms(result)
                    "openAlarmSettings" -> handleOpenAlarmSettings(result)
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Handle show test notification request from Flutter
     * Arguments: map with title and body (optional)
     */
    private fun handleShowTestNotification(arguments: Any?, result: MethodChannel.Result) {
        try {
            val args = arguments as? Map<*, *>
            val title = args?.get("title") as? String ?: "Test Notification"
            val body = args?.get("body") as? String ?: "This is a test notification from native code"

            // Use a high fixed ID for test notifications
            val testId = 999999

            // Show notification immediately
            NotificationHelper(this).showNotification(testId, title, body, null)
            result.success(true)
        } catch (e: Exception) {
            Logger.e("Error in handleShowTestNotification", e)
            result.error("SHOW_TEST_ERROR", e.message, null)
        }
    }
    
    /**
     * Handle schedule alarm request from Flutter
     */
    private fun handleScheduleAlarm(arguments: Any?, result: MethodChannel.Result) {
        try {
            val args = arguments as? Map<*, *>
            if (args == null) {
                result.error("INVALID_ARGS", "Arguments must be a map", null)
                return
            }
            
            val id = args["id"] as? Int
            val title = args["title"] as? String
            val body = args["body"] as? String
            val timestamp = args["timestamp"] as? Long
            val payload = args["payload"] as? String
            
            if (id == null || title == null || body == null || timestamp == null) {
                result.error("MISSING_PARAMS", "Required parameters missing", null)
                return
            }
            
            val success = alarmScheduler.scheduleExactAlarm(
                id = id,
                title = title,
                body = body,
                triggerTimeMillis = timestamp,
                payload = payload
            )
            
            result.success(success)
            
        } catch (e: Exception) {
            Logger.e("Error in handleScheduleAlarm", e)
            result.error("SCHEDULE_ERROR", e.message, null)
        }
    }
    
    /**
     * Handle cancel alarm request from Flutter
     */
    private fun handleCancelAlarm(arguments: Any?, result: MethodChannel.Result) {
        try {
            val id = arguments as? Int
            if (id == null) {
                result.error("INVALID_ID", "ID must be an integer", null)
                return
            }
            
            val success = alarmScheduler.cancelAlarm(id)
            result.success(success)
            
        } catch (e: Exception) {
            Logger.e("Error in handleCancelAlarm", e)
            result.error("CANCEL_ERROR", e.message, null)
        }
    }
    
    /**
     * Handle cancel all alarms request from Flutter
     */
    private fun handleCancelAllAlarms(result: MethodChannel.Result) {
        try {
            val success = alarmScheduler.cancelAllAlarms()
            result.success(success)
        } catch (e: Exception) {
            Logger.e("Error in handleCancelAllAlarms", e)
            result.error("CANCEL_ALL_ERROR", e.message, null)
        }
    }
    
    /**
     * Handle get all scheduled alarms request from Flutter
     */
    private fun handleGetAllScheduledAlarms(result: MethodChannel.Result) {
        try {
            val alarms = alarmScheduler.getAllScheduledAlarms()
            val alarmMaps = alarms.map { alarm ->
                mapOf(
                    "id" to alarm.id,
                    "title" to alarm.title,
                    "body" to alarm.body,
                    "timestamp" to alarm.timestamp,
                    "payload" to (alarm.payload ?: "")
                )
            }
            result.success(alarmMaps)
        } catch (e: Exception) {
            Logger.e("Error in handleGetAllScheduledAlarms", e)
            result.error("GET_ALARMS_ERROR", e.message, null)
        }
    }
    
    /**
     * Check if exact alarm permission is granted
     */
    private fun handleCanScheduleExactAlarms(result: MethodChannel.Result) {
        try {
            val canSchedule = alarmScheduler.canScheduleExactAlarms()
            result.success(canSchedule)
        } catch (e: Exception) {
            Logger.e("Error in handleCanScheduleExactAlarms", e)
            result.error("PERMISSION_CHECK_ERROR", e.message, null)
        }
    }
    
    /**
     * Open system settings for exact alarm permission
     */
    private fun handleOpenAlarmSettings(result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                startActivity(intent)
                result.success(true)
            } else {
                result.success(false) // No settings needed before Android 12
            }
        } catch (e: Exception) {
            Logger.e("Error in handleOpenAlarmSettings", e)
            result.error("SETTINGS_ERROR", e.message, null)
        }
    }
}