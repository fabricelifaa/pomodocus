package com.fab2dev.pomodocus

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingAction: String? = null
    private var homeChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // DND left on by a previous run that was killed in full screen.
        DndController.disable(this)
        pendingAction = HomeActions.fromIntent(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "com.fab2dev.pomodocus/dnd").setMethodCallHandler { call, result ->
            when (call.method) {
                "hasAccess" -> result.success(DndController.hasAccess(this))
                "requestAccess" -> {
                    DndController.openAccessSettings(this)
                    result.success(null)
                }
                "enable" -> result.success(DndController.enable(this))
                "disable" -> {
                    DndController.disable(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        homeChannel = MethodChannel(messenger, "com.fab2dev.pomodocus/home").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialAction" -> {
                        result.success(pendingAction)
                        pendingAction = null
                    }
                    "publishTimer" -> {
                        (call.arguments as? Map<*, *>)?.let { TimerSnapshot.save(this@MainActivity, it) }
                        TimerWidgetProvider.updateAll(this@MainActivity)
                        PomodoroTileService.refresh(this@MainActivity)
                        result.success(null)
                    }
                    "requestPinWidget" -> result.success(TimerWidgetProvider.requestPin(this@MainActivity))
                    "requestAddTile" -> PomodoroTileService.requestAdd(this@MainActivity) { result.success(it) }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        HomeActions.fromIntent(intent)?.let { homeChannel?.invokeMethod("action", it) }
    }

    override fun onDestroy() {
        // Leaving the app for good: never leave the phone in DND.
        if (isFinishing) DndController.disable(this)
        super.onDestroy()
    }
}
