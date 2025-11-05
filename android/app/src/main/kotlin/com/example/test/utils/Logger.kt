package com.example.test.utils

import android.util.Log

/**
 * Centralized logging utility with structured output.
 * All native alarm operations are logged here for debugging.
 */
object Logger {
    private const val TAG = "NativeAlarm"
    private const val ENABLED = true // Set to false in production
    
    fun d(message: String) {
        if (ENABLED) Log.d(TAG, "📘 $message")
    }
    
    fun i(message: String) {
        if (ENABLED) Log.i(TAG, "ℹ️ $message")
    }
    
    fun w(message: String) {
        Log.w(TAG, "⚠️ $message")
    }
    
    fun e(message: String, throwable: Throwable? = null) {
        Log.e(TAG, "❌ $message", throwable)
    }
    
    fun success(message: String) {
        if (ENABLED) Log.i(TAG, "✅ $message")
    }
    
    // Structured logging for alarm operations
    fun logSchedule(id: Int, timestamp: Long, title: String) {
        i("┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        i("┃ SCHEDULING ALARM")
        i("┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        i("┃ ID: $id")
        i("┃ Time: ${java.util.Date(timestamp)}")
        i("┃ Title: $title")
        i("┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    fun logFire(id: Int, title: String) {
        success("🔔 ALARM FIRED: ID=$id, Title=$title")
    }
    
    fun logCancel(id: Int) {
        i("🗑️ ALARM CANCELLED: ID=$id")
    }
    
    fun logBoot() {
        success("🔄 BOOT COMPLETED - Rescheduling alarms")
    }
}