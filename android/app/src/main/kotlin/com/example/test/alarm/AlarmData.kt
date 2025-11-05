package com.example.test.alarm

data class AlarmData(
    val id: Int,
    val title: String,
    val body: String,
    val timestamp: Long,
    val payload: String? = null
)