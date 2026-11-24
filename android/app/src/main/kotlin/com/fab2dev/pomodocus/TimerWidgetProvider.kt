package com.fab2dev.pomodocus

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews

/**
 * Home-screen widget: current session and a live countdown (a Chronometer,
 * so it ticks without waking the app). The button starts or resumes the
 * timer; while running it opens the full-screen countdown.
 */
class TimerWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(ctx: Context, mgr: AppWidgetManager, ids: IntArray) {
        mgr.updateAppWidget(ids, build(ctx))
        scheduleEndRefresh(ctx)
    }

    override fun onReceive(ctx: Context, intent: Intent) {
        super.onReceive(ctx, intent)
        if (intent.action == ACTION_REFRESH) updateAll(ctx)
    }

    companion object {
        private const val ACTION_REFRESH = "com.fab2dev.pomodocus.widget.REFRESH"

        private fun component(ctx: Context) = ComponentName(ctx, TimerWidgetProvider::class.java)

        fun updateAll(ctx: Context) {
            val mgr = AppWidgetManager.getInstance(ctx)
            val ids = mgr.getAppWidgetIds(component(ctx))
            if (ids.isNotEmpty()) mgr.updateAppWidget(ids, build(ctx))
            scheduleEndRefresh(ctx)
        }

        /** Asks the launcher to add the widget (Android 8+ launchers). */
        fun requestPin(ctx: Context): Boolean {
            val mgr = AppWidgetManager.getInstance(ctx)
            if (!mgr.isRequestPinAppWidgetSupported) return false
            return mgr.requestPinAppWidget(component(ctx), null, null)
        }

        private fun build(ctx: Context): RemoteViews {
            val s = TimerSnapshot.load(ctx)
            val rv = RemoteViews(ctx.packageName, R.layout.widget_timer)
            val now = System.currentTimeMillis()
            var action = HomeActions.START
            var icon = R.drawable.ic_widget_play
            var desc = "Démarrer"
            when {
                s.isRunning(now) -> {
                    rv.setTextViewText(R.id.widget_label, s.label)
                    rv.setViewVisibility(R.id.widget_time, View.GONE)
                    rv.setViewVisibility(R.id.widget_chrono, View.VISIBLE)
                    rv.setChronometer(
                        R.id.widget_chrono,
                        SystemClock.elapsedRealtime() + (s.endsAt - now),
                        null,
                        true,
                    )
                    rv.setChronometerCountDown(R.id.widget_chrono, true)
                    action = HomeActions.FULLSCREEN
                    icon = R.drawable.ic_widget_fullscreen
                    desc = "Plein écran"
                }
                s.isFinished(now) -> showStatic(rv, "Session terminée", "00:00")
                s.isPaused -> {
                    showStatic(rv, "En pause · ${s.label}", TimerSnapshot.format(s.remainingSeconds))
                    desc = "Reprendre"
                }
                else -> showStatic(rv, s.label, TimerSnapshot.format(s.remainingSeconds))
            }
            rv.setImageViewResource(R.id.widget_action, icon)
            rv.setContentDescription(R.id.widget_action, desc)
            rv.setOnClickPendingIntent(R.id.widget_root, HomeActions.pending(ctx, null, 10))
            rv.setOnClickPendingIntent(R.id.widget_action, HomeActions.pending(ctx, action, 11))
            return rv
        }

        private fun showStatic(rv: RemoteViews, label: String, time: String) {
            rv.setTextViewText(R.id.widget_label, label)
            rv.setTextViewText(R.id.widget_time, time)
            rv.setViewVisibility(R.id.widget_chrono, View.GONE)
            rv.setViewVisibility(R.id.widget_time, View.VISIBLE)
            rv.setChronometer(R.id.widget_chrono, SystemClock.elapsedRealtime(), null, false)
        }

        /** Switches the widget to "Session terminée" when the countdown ends. */
        private fun scheduleEndRefresh(ctx: Context) {
            val am = ctx.getSystemService(AlarmManager::class.java) ?: return
            val pi = PendingIntent.getBroadcast(
                ctx,
                12,
                Intent(ctx, TimerWidgetProvider::class.java).setAction(ACTION_REFRESH),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            val s = TimerSnapshot.load(ctx)
            if (s.isRunning()) {
                am.set(AlarmManager.RTC, s.endsAt + 500, pi)
            } else {
                am.cancel(pi)
            }
        }
    }
}
