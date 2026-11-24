package com.fab2dev.pomodocus

import android.annotation.SuppressLint
import android.app.Activity
import android.app.StatusBarManager
import android.content.ComponentName
import android.content.Context
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import java.text.DateFormat
import java.util.Date

/** Quick Settings tile: starts a Pomodoro, or opens the countdown if running. */
class PomodoroTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        render()
    }

    override fun onClick() {
        super.onClick()
        val running = TimerSnapshot.load(this).isRunning()
        val action = if (running) HomeActions.FULLSCREEN else HomeActions.START
        if (Build.VERSION.SDK_INT >= 34) {
            startActivityAndCollapse(HomeActions.pending(this, action, 20))
        } else {
            @Suppress("DEPRECATION")
            @SuppressLint("StartActivityAndCollapseDeprecated")
            startActivityAndCollapse(HomeActions.activityIntent(this, action))
        }
    }

    private fun render() {
        val tile = qsTile ?: return
        val s = TimerSnapshot.load(this)
        val running = s.isRunning()
        tile.icon = Icon.createWithResource(this, R.drawable.ic_stat_pomodocus)
        tile.state = if (running) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = if (running) s.label else getString(R.string.tile_label)
        if (Build.VERSION.SDK_INT >= 29) {
            tile.subtitle = when {
                running -> "Fin à " + DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(s.endsAt))
                s.isPaused -> "En pause"
                else -> "Démarrer"
            }
        }
        tile.contentDescription = if (running) "${s.label} en cours" else "Démarrer un Pomodoro"
        tile.updateTile()
    }

    companion object {
        private fun component(ctx: Context) = ComponentName(ctx, PomodoroTileService::class.java)

        fun refresh(ctx: Context) {
            try {
                requestListeningState(ctx, component(ctx))
            } catch (_: Exception) {
                // Tile not added, or launcher refuses: it refreshes when shown.
            }
        }

        /** System prompt to add the tile (Android 13+). Reports the outcome. */
        fun requestAdd(activity: Activity, done: (Boolean) -> Unit) {
            if (Build.VERSION.SDK_INT < 33) return done(false)
            val sbm = activity.getSystemService(StatusBarManager::class.java) ?: return done(false)
            sbm.requestAddTileService(
                component(activity),
                activity.getString(R.string.tile_label),
                Icon.createWithResource(activity, R.drawable.ic_stat_pomodocus),
                activity.mainExecutor,
            ) { result ->
                done(
                    result == StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ADDED ||
                        result == StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ALREADY_ADDED,
                )
            }
        }
    }
}
