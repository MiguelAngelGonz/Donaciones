package com.donation.app.data

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** Guarda el id del usuario con sesión iniciada (CU-07, CU-10). */
class SessionManager(context: Context) {
    private val prefs = context.getSharedPreferences("session", Context.MODE_PRIVATE)
    private val _userId = MutableStateFlow(prefs.getLong(KEY, -1L).takeIf { it > 0 })

    val userId: StateFlow<Long?> = _userId.asStateFlow()
    val currentUserId: Long? get() = _userId.value

    fun open(id: Long) {
        prefs.edit().putLong(KEY, id).apply()
        _userId.value = id
    }

    fun close() {
        prefs.edit().remove(KEY).apply()
        _userId.value = null
    }

    private companion object {
        const val KEY = "user_id"
    }
}
