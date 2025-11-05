package com.example.test.notification

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.example.test.MainActivity
import com.example.test.R
import com.example.test.utils.Logger

/**
 * Handles notification display.
 * Creates channels and shows notifications with proper styling.
 */
class NotificationHelper(private val context: Context) {
    
    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) 
        as NotificationManager
    
    companion object {
        private const val CHANNEL_ID = "medication_reminders"
        private const val CHANNEL_NAME = "Medication Reminders"
        private const val CHANNEL_DESC = "Critical medication reminder notifications"
    }
    
    init {
        createNotificationChannel()
    }
    
    /**
     * Create notification channel (Android 8.0+)
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = CHANNEL_DESC
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
                vibrationPattern = longArrayOf(0, 500, 250, 500)
            }
            
            notificationManager.createNotificationChannel(channel)
            Logger.d("Notification channel created")
        }
    }
    
    /**
     * Show a notification
     */
    fun showNotification(
        id: Int,
        title: String,
        body: String,
        payload: String? = null
    ) {
        try {
            // Intent to open app when notification is tapped
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("notification_payload", payload)
            }
            
            val pendingIntent = PendingIntent.getActivity(
                context,
                id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Build notification
            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher) // Use your app icon
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setVibrate(longArrayOf(0, 500, 250, 500))
                .setLights(0xFF00FF00.toInt(), 1000, 500)
                .build()
            
            // Show notification
            notificationManager.notify(id, notification)
            Logger.logFire(id, title)
            
        } catch (e: Exception) {
            Logger.e("Failed to show notification: ID=$id", e)
        }
    }
    
    /**
     * Cancel a notification
     */
    fun cancelNotification(id: Int) {
        notificationManager.cancel(id)
        Logger.d("Notification cancelled: ID=$id")
    }
}