package com.irl.app.services

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.Duration
import java.time.Instant
import java.time.LocalDate

class ScreenTimeService(
    private val dailyLimitMinutes: Long = 60L
) {
    private var sessionStart: Instant? = null
    private var accumulatedToday: Duration = Duration.ZERO
    private var lastTrackedDate: LocalDate = LocalDate.now()

    private val _elapsedMinutes = MutableStateFlow(0L)
    val elapsedMinutes: StateFlow<Long> = _elapsedMinutes.asStateFlow()

    private val _limitReached = MutableStateFlow(false)
    val limitReached: StateFlow<Boolean> = _limitReached.asStateFlow()

    val dailyLimit: Long get() = dailyLimitMinutes

    val progress: Float
        get() {
            val elapsed = _elapsedMinutes.value
            return (elapsed.toFloat() / dailyLimitMinutes).coerceIn(0f, 1f)
        }

    fun onSessionStart() {
        resetIfNewDay()
        sessionStart = Instant.now()
    }

    fun onSessionEnd() {
        sessionStart?.let { start ->
            val sessionDuration = Duration.between(start, Instant.now())
            accumulatedToday = accumulatedToday.plus(sessionDuration)
            updateState()
        }
        sessionStart = null
    }

    fun updateState() {
        resetIfNewDay()

        val currentSession = sessionStart?.let {
            Duration.between(it, Instant.now())
        } ?: Duration.ZERO

        val totalMinutes = accumulatedToday.plus(currentSession).toMinutes()
        _elapsedMinutes.value = totalMinutes
        _limitReached.value = totalMinutes >= dailyLimitMinutes
    }

    private fun resetIfNewDay() {
        val today = LocalDate.now()
        if (today != lastTrackedDate) {
            accumulatedToday = Duration.ZERO
            lastTrackedDate = today
            _elapsedMinutes.value = 0
            _limitReached.value = false
        }
    }

    fun formattedTime(): String {
        val minutes = _elapsedMinutes.value
        return when {
            minutes < 1 -> "0 min"
            minutes < 60 -> "$minutes min"
            else -> {
                val hours = minutes / 60
                val remainingMin = minutes % 60
                "${hours}h ${remainingMin}m"
            }
        }
    }
}
