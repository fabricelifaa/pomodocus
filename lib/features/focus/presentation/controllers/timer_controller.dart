import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../settings/domain/pomodoro_settings.dart';
import '../../../settings/presentation/settings_controller.dart';
import '../../domain/entities/active_timer_state.dart';
import '../../domain/entities/focus_session.dart';
import '../../domain/entities/session_type.dart';
import '../../domain/pomodoro_engine.dart';

@immutable
class TimerViewState {
  const TimerViewState({
    required this.timer,
    required this.remaining,
    required this.progress,
    this.completionCount = 0,
    this.lastCompleted,
  });

  final ActiveTimerState timer;
  final Duration remaining;

  /// 0 → 1 as the session elapses.
  final double progress;

  /// Increments every time a session completes in the foreground; the UI
  /// listens to it to trigger the end-of-cycle animation.
  final int completionCount;
  final FocusSession? lastCompleted;

  int get remainingSeconds => (remaining.inMilliseconds / 1000).ceil();

  TimerViewState copyWith({
    ActiveTimerState? timer,
    Duration? remaining,
    double? progress,
    int? completionCount,
    FocusSession? lastCompleted,
  }) => TimerViewState(
    timer: timer ?? this.timer,
    remaining: remaining ?? this.remaining,
    progress: progress ?? this.progress,
    completionCount: completionCount ?? this.completionCount,
    lastCompleted: lastCompleted ?? this.lastCompleted,
  );
}

final timerControllerProvider =
    NotifierProvider<TimerController, TimerViewState>(TimerController.new);

/// Orchestrates the pure [PomodoroEngine] with persistence, notifications,
/// sound and haptics. The ticker only refreshes the display: time is always
/// recomputed from the stored deadline.
class TimerController extends Notifier<TimerViewState> {
  Timer? _ticker;
  AppLifecycleListener? _lifecycle;
  final Set<String> _finalizedIds = {};
  bool _finalizing = false;

  PomodoroEngine get _engine => ref.read(engineProvider);
  PomodoroSettings get _settings => ref.read(settingsProvider);

  @override
  TimerViewState build() {
    final engine = ref.watch(engineProvider);
    final saved = ref.read(activeTimerRepositoryProvider).load();
    final settings = ref.read(settingsProvider);
    final initial = saved == null
        ? engine.initial(settings)
        : engine.applySettings(saved, settings);

    ref.listen<PomodoroSettings>(settingsProvider, (prev, next) {
      final updated = _engine.applySettings(state.timer, next);
      if (updated != state.timer) _setTimer(updated);
    });

    _lifecycle = AppLifecycleListener(onResume: sync);
    ref.onDispose(() {
      _ticker?.cancel();
      _lifecycle?.dispose();
    });

    // A session that ended while the app was closed is finalised right away
    // (without sound: the notification already played).
    if (engine.isFinished(initial)) {
      scheduleMicrotask(() => _finalize(initial, late: true));
    } else if (initial.isRunning) {
      _startTicker();
    }
    return _view(initial);
  }

  // ---- Public actions -----------------------------------------------------

  Future<void> start() async {
    final next = _engine.start(state.timer);
    await _apply(next);
  }

  Future<void> pause() async => _apply(_engine.pause(state.timer));

  Future<void> resume() async => _apply(_engine.resume(state.timer));

  Future<void> toggle() async {
    final t = state.timer;
    if (t.isIdle) return start();
    if (t.isRunning) return pause();
    return resume();
  }

  /// Abandons the current session (recorded as interrupted).
  Future<void> reset() async {
    final r = _engine.stop(state.timer, _settings);
    if (r.session != null) await _record(r.session!);
    await _apply(r.next);
  }

  Future<void> skipBreak() async {
    final r = _engine.skipBreak(state.timer, _settings);
    if (r.session != null) await _record(r.session!);
    await _apply(r.next);
  }

  /// Recomputes from the clock (called on resume from background).
  void sync() {
    final t = state.timer;
    if (_engine.isFinished(t)) {
      _finalize(t, late: true);
    } else {
      _refresh();
      if (t.isRunning) _startTicker();
    }
  }

  // ---- Internals ----------------------------------------------------------

  TimerViewState _view(ActiveTimerState t) => TimerViewState(
    timer: t,
    remaining: _engine.remaining(t),
    progress: _engine.progress(t),
    completionCount: _maybeState?.completionCount ?? 0,
    lastCompleted: _maybeState?.lastCompleted,
  );

  TimerViewState? get _maybeState {
    try {
      return state;
    } catch (_) {
      return null;
    }
  }

  void _setTimer(ActiveTimerState t) {
    state = _view(t);
    _persist(t);
  }

  Future<void> _apply(ActiveTimerState next) async {
    final prev = state.timer;
    if (next == prev) return;
    _setTimer(next);
    if (next.isRunning) {
      _startTicker();
      await _scheduleNotification(next);
    } else {
      _ticker?.cancel();
      await ref.read(notificationServiceProvider).cancelSessionEnd();
    }
  }

  void _persist(ActiveTimerState t) {
    ref.read(activeTimerRepositoryProvider).save(t).catchError((Object e) {
      debugPrint('Persist active timer failed: $e');
    });
  }

  void _startTicker() {
    _ticker?.cancel();
    // 250 ms keeps the seconds display aligned with the real clock; the
    // widget only rebuilds when the displayed second changes.
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  void _tick() {
    final t = state.timer;
    if (!t.isRunning) {
      _ticker?.cancel();
      return;
    }
    if (_engine.isFinished(t)) {
      _finalize(t, late: false);
      return;
    }
    _refresh();
  }

  void _refresh() {
    final t = state.timer;
    final remaining = _engine.remaining(t);
    final secs = (remaining.inMilliseconds / 1000).ceil();
    if (secs != state.remainingSeconds || t.isIdle) {
      state = state.copyWith(
        remaining: remaining,
        progress: _engine.progress(t),
      );
    }
  }

  Future<void> _finalize(ActiveTimerState t, {required bool late}) async {
    if (_finalizing || _finalizedIds.contains(t.sessionId)) return;
    _finalizing = true;
    try {
      final r = _engine.complete(t, _settings);
      if (r == null) return;
      _finalizedIds.add(t.sessionId);
      _ticker?.cancel();
      await _record(r.session);
      state = _view(r.next).copyWith(
        completionCount: state.completionCount + (late ? 0 : 1),
        lastCompleted: r.session,
      );
      _persist(r.next);
      if (r.next.isRunning) {
        _startTicker();
        await _scheduleNotification(r.next);
      }
      if (!late) await _feedback();
    } finally {
      _finalizing = false;
    }
  }

  Future<void> _record(FocusSession s) async {
    try {
      await ref.read(sessionRepositoryProvider).record(s);
    } catch (e) {
      debugPrint('Recording session failed: $e');
    }
  }

  Future<void> _feedback() async {
    final s = _settings;
    if (s.soundEnabled) {
      unawaited(ref.read(soundServiceProvider).playSessionEnd());
    }
    if (s.vibrationEnabled) {
      unawaited(ref.read(hapticsServiceProvider).sessionEnd());
    }
  }

  Future<void> _scheduleNotification(ActiveTimerState t) async {
    if (t.endsAt == null) return;
    final s = _settings;
    final (title, body) = switch (t.type) {
      SessionType.focus => (
        'Concentration terminée',
        'Bravo ! Accordez-vous une pause bien méritée.',
      ),
      SessionType.shortBreak => (
        'Pause terminée',
        'Prêt pour le prochain Pomodoro ?',
      ),
      SessionType.longBreak => (
        'Longue pause terminée',
        'Un nouveau cycle commence. Focus on what matters.',
      ),
    };
    await ref
        .read(notificationServiceProvider)
        .scheduleSessionEnd(
          at: t.endsAt!,
          title: title,
          body: body,
          withSound: s.soundEnabled,
          withVibration: s.vibrationEnabled,
        );
  }
}
