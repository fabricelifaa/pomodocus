package com.fab2dev.pomodocus

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import java.util.Locale

/** Intents used by the widget, the Quick Settings tile and the shortcuts. */
object HomeActions {
    const val START = "com.fab2dev.pomodocus.action.START"
    const val FULLSCREEN = "com.fab2dev.pomodocus.action.FULLSCREEN"
    const val STATS = "com.fab2dev.pomodocus.action.STATS"

    /** Name understood by the Flutter side (LaunchAction), or null. */
    fun fromIntent(intent: Intent?): String? = when (intent?.action) {
        START -> "start"
        FULLSCREEN -> "fullscreen"
        STATS -> "stats"
        else -> null
    }

    fun activityIntent(ctx: Context, action: String?): Intent =
        Intent(ctx, MainActivity::class.java).apply {
            if (action != null) this.action = action
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }

    fun pending(ctx: Context, action: String?, requestCode: Int): PendingIntent =
        PendingIntent.getActivity(
            ctx,
            requestCode,
            activityIntent(ctx, action),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
}

/** Last timer state published by the app (the widget and tile read it). */
data class TimerSnapshot(
    val status: String,
    val label: String,
    val endsAt: Long,
    val remainingSeconds: Int,
) {
    fun isRunning(now: Long = System.currentTimeMillis()) = status == "running" && endsAt > now

    fun isFinished(now: Long = System.currentTimeMillis()) = status == "running" && endsAt <= now

    val isPaused get() = status == "paused"

    companion object {
        private const val PREFS = "pomodocus_home"

        fun load(ctx: Context): TimerSnapshot {
            val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            return TimerSnapshot(
                status = p.getString("status", "idle") ?: "idle",
                label = p.getString("label", "Concentration") ?: "Concentration",
                endsAt = p.getLong("endsAt", -1),
                remainingSeconds = p.getInt("remaining", 25 * 60),
            )
        }

        fun save(ctx: Context, args: Map<*, *>) {
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString("status", args["status"] as? String ?: "idle")
                .putString("label", args["label"] as? String ?: "Concentration")
                .putLong("endsAt", (args["endsAt"] as? Number)?.toLong() ?: -1)
                .putInt("remaining", (args["remainingSeconds"] as? Number)?.toInt() ?: 0)
                .apply()
        }

        fun format(seconds: Int): String {
            val s = seconds.coerceAtLeast(0)
            return String.format(Locale.ROOT, "%02d:%02d", s / 60, s % 60)
        }
    }
}
