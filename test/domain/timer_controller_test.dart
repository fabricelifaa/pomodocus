import 'package:flutter_test/flutter_test.dart';
import 'package:pomodocus/features/focus/domain/entities/session_type.dart';
import 'package:pomodocus/features/focus/presentation/controllers/timer_controller.dart';
import 'package:pomodocus/features/settings/presentation/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDeps deps;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    deps = TestDeps(await SharedPreferences.getInstance());
  });

  test('start schedules the end notification at the deadline', () async {
    final c = deps.container();
    addTearDown(c.dispose);
    await c.read(timerControllerProvider.notifier).start();
    final t = c.read(timerControllerProvider).timer;
    expect(t.isRunning, isTrue);
    expect(deps.notifications.scheduled.single, t.endsAt);
  });

  test('pause cancels the notification, resume reschedules it', () async {
    final c = deps.container();
    addTearDown(c.dispose);
    final ctl = c.read(timerControllerProvider.notifier);
    await ctl.start();
    deps.clock.advance(const Duration(minutes: 5));
    await ctl.pause();
    expect(deps.notifications.cancelCount, greaterThan(0));
    expect(c.read(timerControllerProvider).remainingSeconds, 20 * 60);
    deps.clock.advance(const Duration(minutes: 10));
    await ctl.resume();
    expect(
      deps.notifications.scheduled.last,
      deps.clock.now().add(const Duration(minutes: 20)),
    );
  });

  test(
    'a finished session is recorded exactly once, even on repeated syncs',
    () async {
      final c = deps.container();
      addTearDown(c.dispose);
      final ctl = c.read(timerControllerProvider.notifier);
      await ctl.start();
      deps.clock.advance(const Duration(minutes: 25, seconds: 2));
      ctl.sync();
      ctl.sync();
      await Future<void>.delayed(Duration.zero);
      ctl.sync();
      await Future<void>.delayed(Duration.zero);
      expect(deps.sessions.rows, hasLength(1));
      expect(deps.sessions.recordCalls, 1);
      final v = c.read(timerControllerProvider);
      expect(v.timer.type, SessionType.shortBreak);
      expect(v.timer.isIdle, isTrue);
    },
  );

  test('restores a running session after an app restart', () async {
    final c1 = deps.container();
    await c1.read(timerControllerProvider.notifier).start();
    deps.clock.advance(const Duration(minutes: 10));
    c1.dispose();

    final c2 = deps.container();
    addTearDown(c2.dispose);
    final v = c2.read(timerControllerProvider);
    expect(v.timer.isRunning, isTrue);
    expect(v.remainingSeconds, 15 * 60);
  });

  test('a session that ended while the app was closed is recorded on restore', () async {
    final c1 = deps.container();
    await c1.read(timerControllerProvider.notifier).start();
    c1.dispose();
    deps.clock.advance(const Duration(hours: 1));

    final c2 = deps.container();
    addTearDown(c2.dispose);
    c2.read(timerControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(deps.sessions.rows.values.single.isCompleted, isTrue);
    expect(c2.read(timerControllerProvider).timer.type, SessionType.shortBreak);
    // No sound for a completion detected late (the notification already rang).
    expect(deps.sound.plays, 0);
  });

  test('reset records an interrupted session', () async {
    final c = deps.container();
    addTearDown(c.dispose);
    final ctl = c.read(timerControllerProvider.notifier);
    await ctl.start();
    deps.clock.advance(const Duration(minutes: 3));
    await ctl.reset();
    final s = deps.sessions.rows.values.single;
    expect(s.isCompleted, isFalse);
    expect(s.actualDurationSeconds, 180);
    expect(c.read(timerControllerProvider).timer.isIdle, isTrue);
  });

  test('changing durations only affects an idle session', () async {
    final c = deps.container();
    addTearDown(c.dispose);
    final ctl = c.read(timerControllerProvider.notifier);
    await c
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(focusDurationMinutes: 40));
    expect(c.read(timerControllerProvider).remainingSeconds, 40 * 60);
    await ctl.start();
    await c
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(focusDurationMinutes: 10));
    expect(
      c.read(timerControllerProvider).timer.plannedDurationSeconds,
      40 * 60,
    );
  });
}
