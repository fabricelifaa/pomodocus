import '../../../core/utils/clock.dart';
import '../../settings/domain/pomodoro_settings.dart';
import 'entities/active_timer_state.dart';
import 'entities/focus_session.dart';
import 'entities/session_type.dart';

typedef IdGenerator = String Function();

class CompletionResult {
  const CompletionResult({
    required this.session,
    required this.next,
    required this.autoStarted,
  });

  final FocusSession session;
  final ActiveTimerState next;
  final bool autoStarted;
}

class StopResult {
  const StopResult({required this.next, this.session});

  /// Interrupted session to record, or null if nothing had started.
  final FocusSession? session;
  final ActiveTimerState next;
}

/// Pure Pomodoro rules. No Flutter, no I/O: every transition takes a state
/// and returns a new one. Time comes from the injected [Clock].
///
/// Cycle rule: `cycleNumber` is the index (1..longBreakInterval) of the focus
/// session within the current set. A focus completed with
/// `cycleNumber >= longBreakInterval` leads to a long break; after the long
/// break the counter restarts at 1. After a short break it increments.
class PomodoroEngine {
  PomodoroEngine({required this.clock, required this.newId});

  final Clock clock;
  final IdGenerator newId;

  ActiveTimerState initial(PomodoroSettings s) =>
      idleFor(SessionType.focus, 1, s);

  ActiveTimerState idleFor(SessionType type, int cycle, PomodoroSettings s) =>
      ActiveTimerState(
        sessionId: newId(),
        type: type,
        status: TimerStatus.idle,
        plannedDurationSeconds: s.durationSecondsFor(type),
        cycleNumber: cycle < 1 ? 1 : cycle,
      );

  // ---- Transitions --------------------------------------------------------

  ActiveTimerState start(ActiveTimerState st) {
    if (!st.isIdle) return st;
    final now = clock.now();
    return st.copyWith(
      status: TimerStatus.running,
      startedAt: now,
      endsAt: now.add(Duration(seconds: st.plannedDurationSeconds)),
      clearRemaining: true,
    );
  }

  ActiveTimerState pause(ActiveTimerState st) {
    if (!st.isRunning) return st;
    return st.copyWith(
      status: TimerStatus.paused,
      remainingSecondsAtPause: remainingSeconds(st),
      clearEndsAt: true,
    );
  }

  ActiveTimerState resume(ActiveTimerState st) {
    if (!st.isPaused) return st;
    final now = clock.now();
    return st.copyWith(
      status: TimerStatus.running,
      endsAt: now.add(Duration(seconds: st.remainingSecondsAtPause ?? 0)),
      clearRemaining: true,
    );
  }

  /// Completes a running session whose deadline has passed. Returns null
  /// when the session is not finished (e.g. a duplicate end event).
  CompletionResult? complete(ActiveTimerState st, PomodoroSettings s) {
    if (!isFinished(st)) return null;
    final session = FocusSession(
      id: st.sessionId,
      type: st.type,
      startedAt: st.startedAt!,
      plannedDurationSeconds: st.plannedDurationSeconds,
      endedAt: st.endsAt,
      actualDurationSeconds: st.plannedDurationSeconds,
      status: SessionStatus.completed,
      cycleNumber: st.cycleNumber,
    );
    final (nextType, nextCycle) = nextAfter(st.type, st.cycleNumber, s);
    var next = idleFor(nextType, nextCycle, s);
    final auto = st.type == SessionType.focus
        ? s.autoStartBreaks
        : s.autoStartFocus;
    if (auto) next = start(next);
    return CompletionResult(session: session, next: next, autoStarted: auto);
  }

  /// "Réinitialiser": abandons the current session (recorded as interrupted
  /// when it had started) and goes back to an idle session of the same kind.
  /// When already idle, resets the whole set to the first focus session.
  StopResult stop(ActiveTimerState st, PomodoroSettings s) {
    if (st.isIdle) return StopResult(next: initial(s));
    return StopResult(
      session: _interrupted(st),
      next: idleFor(st.type, st.cycleNumber, s),
    );
  }

  /// Skips the current break (or idle break) and moves to the next focus.
  StopResult skipBreak(ActiveTimerState st, PomodoroSettings s) {
    if (!st.type.isBreak) return StopResult(next: st);
    final (t, c) = nextAfter(st.type, st.cycleNumber, s);
    return StopResult(
      session: st.isIdle ? null : _interrupted(st),
      next: idleFor(t, c, s),
    );
  }

  /// New settings only affect an idle session; a session that has started
  /// keeps its planned duration until the user explicitly resets it.
  ActiveTimerState applySettings(ActiveTimerState st, PomodoroSettings s) {
    if (!st.isIdle) return st;
    final planned = s.durationSecondsFor(st.type);
    return planned == st.plannedDurationSeconds
        ? st
        : st.copyWith(plannedDurationSeconds: planned);
  }

  (SessionType, int) nextAfter(SessionType t, int cycle, PomodoroSettings s) =>
      switch (t) {
        SessionType.focus =>
          cycle >= s.longBreakInterval
              ? (SessionType.longBreak, cycle)
              : (SessionType.shortBreak, cycle),
        SessionType.shortBreak => (SessionType.focus, cycle + 1),
        SessionType.longBreak => (SessionType.focus, 1),
      };

  // ---- Time queries -------------------------------------------------------

  /// Remaining time computed from the wall clock and the stored deadline.
  /// Clamped to [0, planned] so that moving the phone clock backwards can
  /// never produce more time than planned.
  Duration remaining(ActiveTimerState st) {
    final planned = Duration(seconds: st.plannedDurationSeconds);
    switch (st.status) {
      case TimerStatus.idle:
        return planned;
      case TimerStatus.paused:
        return Duration(seconds: st.remainingSecondsAtPause ?? 0);
      case TimerStatus.running:
        final left = st.endsAt!.difference(clock.now());
        if (left.isNegative) return Duration.zero;
        return left > planned ? planned : left;
    }
  }

  int remainingSeconds(ActiveTimerState st) {
    final ms = remaining(st).inMilliseconds;
    return (ms / 1000).ceil();
  }

  /// 0.0 at start, 1.0 when finished.
  double progress(ActiveTimerState st) {
    final total = st.plannedDurationSeconds * 1000;
    if (total <= 0) return 1;
    return (1 - remaining(st).inMilliseconds / total).clamp(0.0, 1.0);
  }

  bool isFinished(ActiveTimerState st) =>
      st.isRunning && !clock.now().isBefore(st.endsAt!);

  FocusSession? _interrupted(ActiveTimerState st) {
    if (st.startedAt == null) return null;
    final elapsed = st.plannedDurationSeconds - remainingSeconds(st);
    if (elapsed <= 0) return null;
    return FocusSession(
      id: st.sessionId,
      type: st.type,
      startedAt: st.startedAt!,
      plannedDurationSeconds: st.plannedDurationSeconds,
      endedAt: clock.now(),
      actualDurationSeconds: elapsed,
      status: SessionStatus.interrupted,
      cycleNumber: st.cycleNumber,
    );
  }
}
