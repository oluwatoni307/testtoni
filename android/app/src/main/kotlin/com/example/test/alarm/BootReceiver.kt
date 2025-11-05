package com.example.test

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED ||
            intent?.action == Intent.ACTION_LOCKED_BOOT_COMPLETED) {
            Log.d("BootReceiver", "✅ Device rebooted — alarms should be rescheduled here")
            // ⚠️ Optional: you can call your own logic here
            // e.g., re-schedule alarms using stored data in SharedPreferences.
        }
    }
}
