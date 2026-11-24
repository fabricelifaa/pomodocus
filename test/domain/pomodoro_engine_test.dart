import 'package:flutter_test/flutter_test.dart';
import 'package:pomodocus/core/utils/clock.dart';
import 'package:pomodocus/features/focus/domain/entities/active_timer_state.dart';
import 'package:pomodocus/features/focus/domain/entities/session_type.dart';
import 'package:pomodocus/features/focus/domain/pomodoro_engine.dart';
import 'package:pomodocus/features/settings/domain/pomodoro_settings.dart';

void main() {
  late FakeClock clock;
  late PomodoroEngine engine;
  const s = PomodoroSettings.defaults;
  var idCounter = 0;

  setUp(() {
    idCounter = 0;
    clock = FakeClock(DateTime(2026, 11, 24, 9));
    engine = PomodoroEngine(clock: clock, newId: () => 'id${idCounter++}');
  });

  ActiveTimerState finishCurrent(ActiveTimerState st) {
    clock.advance(Duration(seconds: st.plannedDurationSeconds));
    return engine.complete(st, s)!.next;
  }

  group('start / pause / resume', () {
    test('initial state is an idle 25 min focus, cycle 1', () {
      final st = engine.initial(s);
      expect(st.status, TimerStatus.idle);
      expect(st.type, SessionType.focus);
      expect(st.cycleNumber, 1);
      expect(engine.remainingSeconds(st), 25 * 60);
    });

    test('start sets startedAt and endsAt from the clock', () {
      final st = engine.start(engine.initial(s));
      expect(st.isRunning, isTrue);
      expect(st.startedAt, clock.now());
      expect(st.endsAt, clock.now().add(const Duration(minutes: 25)));
    });

    test('remaining time is computed from the clock', () {
      final st = engine.start(engine.initial(s));
      clock.advance(const Duration(minutes: 10, seconds: 30));
      expect(engine.remainingSeconds(st), 14 * 60 + 30);
      expect(engine.progress(st), closeTo(10.5 / 25, 1e-9));
    });

    test('pause freezes remaining time, resume pushes the deadline', () {
      var st = engine.start(engine.initial(s));
      clock.advance(const Duration(minutes: 5));
      st = engine.pause(st);
      expect(st.isPaused, isTrue);
      expect(st.remainingSecondsAtPause, 20 * 60);
      clock.advance(const Duration(hours: 1));
      expect(engine.remainingSeconds(st), 20 * 60);
      st = engine.resume(st);
      expect(st.endsAt, clock.now().add(const Duration(minutes: 20)));
      expect(engine.remainingSeconds(st), 20 * 60);
    });

    test('transitions are no-ops from the wrong status', () {
      final idle = engine.initial(s);
      expect(engine.pause(idle), idle);
      expect(engine.resume(idle), idle);
      final running = engine.start(idle);
      expect(engine.start(running), running);
    });
  });

  group('completion and cycles', () {
    test('not finished before the deadline', () {
      final st = engine.start(engine.initial(s));
      clock.advance(const Duration(minutes: 24, seconds: 59));
      expect(engine.isFinished(st), isFalse);
      expect(engine.complete(st, s), isNull);
    });

    test(
      'focus completion records a completed session and proposes a short break',
      () {
        final st = engine.start(engine.initial(s));
        clock.advance(const Duration(minutes: 25));
        final r = engine.complete(st, s)!;
        expect(r.session.status, SessionStatus.completed);
        expect(r.session.actualDurationSeconds, 25 * 60);
        expect(r.session.id, st.sessionId);
        expect(r.next.type, SessionType.shortBreak);
        expect(r.next.isIdle, isTrue);
        expect(r.next.cycleNumber, 1);
        expect(r.next.plannedDurationSeconds, 5 * 60);
      },
    );

    test(
      'long break after the configured number of pomodoros, then reset to 1',
      () {
        var st = engine.initial(s);
        for (var i = 1; i <= 4; i++) {
          expect(st.type, SessionType.focus);
          expect(st.cycleNumber, i);
          st = finishCurrent(engine.start(st));
          expect(
            st.type,
            i < 4 ? SessionType.shortBreak : SessionType.longBreak,
          );
          st = finishCurrent(engine.start(st));
        }
        expect(st.type, SessionType.focus);
        expect(st.cycleNumber, 1);
      },
    );

    test('long break interval is configurable', () {
      final s2 = s.copyWith(longBreakInterval: 2);
      var st = engine.start(engine.initial(s2));
      clock.advance(const Duration(minutes: 25));
      st = engine.complete(st, s2)!.next; // short break
      st = engine.start(st);
      clock.advance(const Duration(minutes: 5));
      st = engine.complete(st, s2)!.next; // focus 2
      st = engine.start(st);
      clock.advance(const Duration(minutes: 25));
      expect(engine.complete(st, s2)!.next.type, SessionType.longBreak);
    });

    test('auto start breaks / focus', () {
      final auto = s.copyWith(autoStartBreaks: true, autoStartFocus: false);
      var st = engine.start(engine.initial(auto));
      clock.advance(const Duration(minutes: 25));
      final r = engine.complete(st, auto)!;
      expect(r.autoStarted, isTrue);
      expect(r.next.isRunning, isTrue);
      expect(r.next.type, SessionType.shortBreak);
      clock.advance(const Duration(minutes: 5));
      final r2 = engine.complete(r.next, auto)!;
      expect(r2.autoStarted, isFalse);
      expect(r2.next.isIdle, isTrue);
    });

    test('a double end event cannot record twice', () {
      final st = engine.start(engine.initial(s));
      clock.advance(const Duration(minutes: 26));
      final first = engine.complete(st, s)!;
      // The second event is delivered against the new state: nothing to do.
      expect(engine.complete(first.next, s), isNull);
      // Even against the stale state, the session id is identical so the
      // repository de-duplicates it.
      expect(engine.complete(st, s)!.session.id, first.session.id);
    });

    test('completion uses the theoretical end time when detected late', () {
      final st = engine.start(engine.initial(s));
      clock.advance(const Duration(hours: 3));
      final r = engine.complete(st, s)!;
      expect(r.session.endedAt, st.endsAt);
      expect(r.session.actualDurationSeconds, 25 * 60);
    });
  });

  group('stop / skip', () {
    test('stop records an interrupted session with the elapsed time', () {
      final st = engine.start(engine.initial(s));
      clock.advance(const Duration(minutes: 7));
      final r = engine.stop(st, s);
      expect(r.session!.status, SessionStatus.interrupted);
      expect(r.session!.actualDurationSeconds, 7 * 60);
      expect(r.next.isIdle, isTrue);
      expect(r.next.type, SessionType.focus);
      expect(r.next.sessionId, isNot(st.sessionId));
    });

    test('stop while paused uses the paused remaining time', () {
      var st = engine.start(engine.initial(s));
      clock.advance(const Duration(minutes: 3));
      st = engine.pause(st);
      clock.advance(const Duration(minutes: 30));
      expect(engine.stop(st, s).session!.actualDurationSeconds, 3 * 60);
    });

    test('stop when idle resets the set to the first pomodoro', () {
      var st = finishCurrent(engine.start(engine.initial(s)));
      st = finishCurrent(engine.start(st)); // focus #2 idle
      expect(st.cycleNumber, 2);
      final r = engine.stop(st, s);
      expect(r.session, isNull);
      expect(r.next.cycleNumber, 1);
    });

    test('skipping a break goes to the next focus', () {
      final brk = finishCurrent(engine.start(engine.initial(s)));
      final r = engine.skipBreak(brk, s);
      expect(r.session, isNull);
      expect(r.next.type, SessionType.focus);
      expect(r.next.cycleNumber, 2);
    });
  });

  group('settings and restoration', () {
    test('changing settings during a session does not alter it', () {
      final running = engine.start(engine.initial(s));
      final s2 = s.copyWith(focusDurationMinutes: 50);
      expect(engine.applySettings(running, s2), running);
      final idle = engine.initial(s);
      expect(engine.applySettings(idle, s2).plannedDurationSeconds, 50 * 60);
    });

    test('a running state survives JSON round-trip and keeps counting', () {
      final st = engine.start(engine.initial(s));
      final restored = ActiveTimerState.tryFromJson(st.toJson())!;
      expect(restored, st);
      clock.advance(const Duration(minutes: 10));
      expect(engine.remainingSeconds(restored), 15 * 60);
    });

    test(
      'a session that ended while the app was closed is completed on restore',
      () {
        final st = engine.start(engine.initial(s));
        final saved = ActiveTimerState.tryFromJson(st.toJson())!;
        clock.advance(const Duration(minutes: 40));
        expect(engine.isFinished(saved), isTrue);
        expect(
          engine.complete(saved, s)!.session.status,
          SessionStatus.completed,
        );
      },
    );

    test('corrupted persisted state is rejected', () {
      expect(ActiveTimerState.tryFromJson({'foo': 1}), isNull);
      expect(
        ActiveTimerState.tryFromJson({
          'sessionId': 'x',
          'status': 'running',
          'plannedDurationSeconds': 60,
          'cycleNumber': 1,
        }),
        isNull,
      );
    });
  });

  group('system clock changes', () {
    test('clock moved backwards never yields more than planned', () {
      final st = engine.start(engine.initial(s));
      clock.advance(const Duration(hours: -2));
      expect(engine.remainingSeconds(st), 25 * 60);
      expect(engine.isFinished(st), isFalse);
    });

    test('clock moved forwards finishes the session', () {
      final st = engine.start(engine.initial(s));
      clock.advance(const Duration(hours: 2));
      expect(engine.remainingSeconds(st), 0);
      expect(engine.isFinished(st), isTrue);
    });
  });

  test('settings are validated against bounds', () {
    final v = PomodoroSettings.fromJson({
      'focusDurationMinutes': 0,
      'shortBreakMinutes': 999,
      'longBreakInterval': 1,
    });
    expect(v.focusDurationMinutes, SettingsBounds.focusMin);
    expect(v.shortBreakMinutes, SettingsBounds.shortMax);
    expect(v.longBreakInterval, SettingsBounds.intervalMin);
    expect(v.longBreakMinutes, 15);
  });
}
