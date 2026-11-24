package com.fab2dev.pomodocus

import android.app.NotificationManager
import android.app.NotificationManager.Policy
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings

/**
 * "Ne pas déranger" during the full-screen countdown: no calls, no message
 * notifications; alarms, media (the app's own sounds) and system sounds still
 * play. The user's own DND filter and policy are saved first and restored by
 * [disable] — also at the next launch if the app was killed meanwhile.
 */
object DndController {
    private const val PREFS = "pomodocus_dnd"

    private fun nm(ctx: Context) = ctx.getSystemService(NotificationManager::class.java)

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun hasAccess(ctx: Context): Boolean = nm(ctx).isNotificationPolicyAccessGranted

    fun openAccessSettings(ctx: Context) {
        val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            ctx.startActivity(intent)
        } catch (_: ActivityNotFoundException) {
            ctx.startActivity(
                Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    fun enable(ctx: Context): Boolean {
        val nm = nm(ctx)
        if (!nm.isNotificationPolicyAccessGranted) return false
        return try {
            val p = prefs(ctx)
            if (!p.getBoolean("active", false)) {
                val pol = nm.notificationPolicy
                val e = p.edit()
                    .putInt("filter", nm.currentInterruptionFilter)
                    .putInt("cats", pol.priorityCategories)
                    .putInt("calls", pol.priorityCallSenders)
                    .putInt("msgs", pol.priorityMessageSenders)
                    .putInt("visual", pol.suppressedVisualEffects)
                if (Build.VERSION.SDK_INT >= 30) e.putInt("conv", pol.priorityConversationSenders)
                e.putBoolean("active", true).commit()
            }
            nm.notificationPolicy = focusPolicy()
            nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
            true
        } catch (_: SecurityException) {
            false
        }
    }

    fun disable(ctx: Context) {
        val p = prefs(ctx)
        if (!p.getBoolean("active", false)) return
        val nm = nm(ctx)
        if (nm.isNotificationPolicyAccessGranted) {
            try {
                val cats = p.getInt("cats", 0)
                val calls = p.getInt("calls", 0)
                val msgs = p.getInt("msgs", 0)
                val visual = p.getInt("visual", 0)
                nm.notificationPolicy = if (Build.VERSION.SDK_INT >= 30) {
                    Policy(cats, calls, msgs, visual, p.getInt("conv", Policy.CONVERSATION_SENDERS_NONE))
                } else {
                    Policy(cats, calls, msgs, visual)
                }
                val filter = p.getInt("filter", NotificationManager.INTERRUPTION_FILTER_ALL)
                nm.setInterruptionFilter(
                    if (filter == NotificationManager.INTERRUPTION_FILTER_UNKNOWN) {
                        NotificationManager.INTERRUPTION_FILTER_ALL
                    } else {
                        filter
                    },
                )
            } catch (_: SecurityException) {
                // Access revoked meanwhile: nothing we can restore.
            }
        }
        p.edit().clear().commit()
    }

    /** Only alarms, media and system sounds get through. */
    private fun focusPolicy(): Policy {
        var cats = Policy.PRIORITY_CATEGORY_ALARMS
        val visual: Int
        if (Build.VERSION.SDK_INT >= 28) {
            cats = cats or Policy.PRIORITY_CATEGORY_MEDIA or Policy.PRIORITY_CATEGORY_SYSTEM
            visual = Policy.SUPPRESSED_EFFECT_PEEK or
                Policy.SUPPRESSED_EFFECT_FULL_SCREEN_INTENT or
                Policy.SUPPRESSED_EFFECT_LIGHTS
        } else {
            @Suppress("DEPRECATION")
            visual = Policy.SUPPRESSED_EFFECT_SCREEN_ON or Policy.SUPPRESSED_EFFECT_SCREEN_OFF
        }
        return if (Build.VERSION.SDK_INT >= 30) {
            Policy(cats, 0, 0, visual, Policy.CONVERSATION_SENDERS_NONE)
        } else {
            Policy(cats, 0, 0, visual)
        }
    }
}
