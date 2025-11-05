package com.example.test.alarm

import android.content.Context
import android.content.SharedPreferences
import com.example.test.utils.Logger
import org.json.JSONArray
import org.json.JSONObject

/**
 * Persists alarm data in SharedPreferences.
 * This ensures alarms survive app kills and reboots.
 */
class AlarmStorage(context: Context) {
    
    private val prefs: SharedPreferences = context.getSharedPreferences(
        "native_alarms",
        Context.MODE_PRIVATE
    )
    
    companion object {
        private const val KEY_ALARMS = "alarms"
    }
    
    data class AlarmData(
        val id: Int,
        val title: String,
        val body: String,
        val timestamp: Long,
        val payload: String? = null
    )
    
    /**
     * Save an alarm to storage
     */
    fun saveAlarm(alarm: AlarmData) {
        try {
            val alarms = getAllAlarms().toMutableList()
            
            // Remove existing alarm with same ID
            alarms.removeAll { it.id == alarm.id }
            
            // Add new alarm
            alarms.add(alarm)
            
            // Save to prefs
            val jsonArray = JSONArray()
            alarms.forEach { a ->
                val json = JSONObject().apply {
                    put("id", a.id)
                    put("title", a.title)
                    put("body", a.body)
                    put("timestamp", a.timestamp)
                    put("payload", a.payload ?: "")
                }
                jsonArray.put(json)
            }
            
            prefs.edit().putString(KEY_ALARMS, jsonArray.toString()).apply()
            Logger.d("Alarm saved: ID=${alarm.id}, Total=${alarms.size}")
            
        } catch (e: Exception) {
            Logger.e("Failed to save alarm", e)
        }
    }
    
    /**
     * Get alarm by ID
     */
    fun getAlarm(id: Int): AlarmData? {
        return getAllAlarms().find { it.id == id }
    }
    
    /**
     * Get all stored alarms
     */
    fun getAllAlarms(): List<AlarmData> {
        try {
            val json = prefs.getString(KEY_ALARMS, "[]") ?: "[]"
            val jsonArray = JSONArray(json)
            val alarms = mutableListOf<AlarmData>()
            
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                alarms.add(
                    AlarmData(
                        id = obj.getInt("id"),
                        title = obj.getString("title"),
                        body = obj.getString("body"),
                        timestamp = obj.getLong("timestamp"),
                        payload = obj.optString("payload", null)
                    )
                )
            }
            
            return alarms
        } catch (e: Exception) {
            Logger.e("Failed to load alarms", e)
            return emptyList()
        }
    }
    
    /**
     * Delete an alarm
     */
    fun deleteAlarm(id: Int) {
        try {
            val alarms = getAllAlarms().filter { it.id != id }
            
            val jsonArray = JSONArray()
            alarms.forEach { a ->
                val json = JSONObject().apply {
                    put("id", a.id)
                    put("title", a.title)
                    put("body", a.body)
                    put("timestamp", a.timestamp)
                    put("payload", a.payload ?: "")
                }
                jsonArray.put(json)
            }
            
            prefs.edit().putString(KEY_ALARMS, jsonArray.toString()).apply()
            Logger.d("Alarm deleted: ID=$id, Remaining=${alarms.size}")
            
        } catch (e: Exception) {
            Logger.e("Failed to delete alarm", e)
        }
    }
    
    /**
     * Clear all alarms
     */
    fun clearAll() {
        prefs.edit().clear().apply()
        Logger.i("All alarms cleared")
    }
    
    /**
     * Get alarms that should be rescheduled (not expired)
     */
    fun getActiveAlarms(): List<AlarmData> {
        val now = System.currentTimeMillis()
        return getAllAlarms().filter { it.timestamp > now }
    }
}