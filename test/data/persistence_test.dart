import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodocus/core/config/remote_config_service.dart';
import 'package:pomodocus/core/storage/app_database.dart';
import 'package:pomodocus/core/utils/clock.dart';
import 'package:pomodocus/features/focus/data/drift_session_repository.dart';
import 'package:pomodocus/features/focus/data/prefs_active_timer_repository.dart';
import 'package:pomodocus/features/focus/domain/entities/focus_session.dart';
import 'package:pomodocus/features/focus/domain/entities/session_type.dart';
import 'package:pomodocus/features/focus/domain/pomodoro_engine.dart';
import 'package:pomodocus/features/settings/data/settings_repository.dart';
import 'package:pomodocus/features/settings/domain/pomodoro_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

FocusSession session(String id, DateTime start, {bool done = true}) =>
    FocusSession(
      id: id,
      type: SessionType.focus,
      startedAt: start,
      plannedDurationSeconds: 1500,
      endedAt: start.add(const Duration(minutes: 25)),
      actualDurationSeconds: done ? 1500 : 600,
      status: done ? SessionStatus.completed : SessionStatus.interrupted,
      cycleNumber: 1,
    );

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('settings', () {
    test('defaults when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SettingsRepository(await SharedPreferences.getInstance());
      expect(repo.load(), PomodoroSettings.defaults);
    });

    test('save then load (survives a new instance)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final s = PomodoroSettings.defaults.copyWith(
        focusDurationMinutes: 50,
        autoStartBreaks: true,
        themeMode: AppThemePreference.dark,
      );
      await SettingsRepository(prefs).save(s);
      expect(SettingsRepository(prefs).load(), s);
    });

    test('corrupted json falls back to defaults', () async {
      SharedPreferences.setMockInitialValues({SettingsRepository.key: '{oops'});
      final repo = SettingsRepository(await SharedPreferences.getInstance());
      expect(repo.load(), PomodoroSettings.defaults);
    });
  });

  group('active timer', () {
    test('running state is restored with its deadline', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final clock = FakeClock(DateTime(2026, 11, 24, 10));
      final engine = PomodoroEngine(clock: clock, newId: () => 'abc');
      final running = engine.start(engine.initial(PomodoroSettings.defaults));
      await PrefsActiveTimerRepository(prefs).save(running);
      final restored = PrefsActiveTimerRepository(prefs).load();
      expect(restored, running);
      await PrefsActiveTimerRepository(prefs).clear();
      expect(PrefsActiveTimerRepository(prefs).load(), isNull);
    });
  });

  group('history (drift)', () {
    late AppDatabase db;
    late DriftSessionRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = DriftSessionRepository(db);
    });
    tearDown(() => db.close());

    test('records and reads sessions', () async {
      final now = DateTime(2026, 11, 24, 10);
      await repo.record(session('a', now));
      await repo.record(
        session('b', now.add(const Duration(hours: 1)), done: false),
      );
      final all = await repo.since(DateTime(2026, 11, 24));
      expect(all.map((s) => s.id), ['b', 'a']);
      expect(all.last, session('a', now));
      expect(all.first.status, SessionStatus.interrupted);
    });

    test('recording the same session twice keeps one row', () async {
      final now = DateTime(2026, 11, 24, 10);
      await repo.record(session('same', now));
      await repo.record(session('same', now));
      expect(await repo.since(DateTime(2000)), hasLength(1));
    });

    test('filters by start date', () async {
      await repo.record(session('old', DateTime(2026, 11, 1)));
      await repo.record(session('new', DateTime(2026, 11, 24)));
      final r = await repo.since(DateTime(2026, 11, 18));
      expect(r.map((s) => s.id), ['new']);
    });

    test('schema version and migrations are declared', () async {
      expect(db.schemaVersion, 1);
      // Creating the schema from scratch must succeed (onCreate path).
      await db.customSelect('SELECT 1').get();
      final idx = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_sessions_started'",
          )
          .get();
      expect(idx, hasLength(1));
    });
  });

  group('remote config', () {
    test('falls back to defaults and validates input', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final svc = RemoteConfigService(
        prefs: prefs,
        source: _Fixed({
          'feature_tasks_enabled': true,
          'feature_habits_enabled': 'yes', // invalid type → false
          'minimum_supported_version': '1.2.0',
          'recommended_version': 'latest', // invalid → null
        }),
      );
      expect(svc.cached.featureTasksEnabled, isFalse);
      final c = await svc.refresh();
      expect(c.featureTasksEnabled, isTrue);
      expect(c.featureHabitsEnabled, isFalse);
      expect(c.minimumSupportedVersion, '1.2.0');
      expect(c.recommendedVersion, isNull);
      // Cached for the next launch.
      expect(
        RemoteConfigService(prefs: prefs).cached.featureTasksEnabled,
        isTrue,
      );
    });

    test('network failure keeps the cached config', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final svc = RemoteConfigService(prefs: prefs, source: _Failing());
      final c = await svc.refresh();
      expect(c.maintenanceMode, isFalse);
      expect(c.featureTasksEnabled, isFalse);
    });
  });
}

class _Fixed implements RemoteConfigSource {
  _Fixed(this.data);
  final Map<String, Object?> data;
  @override
  Future<Map<String, Object?>> fetch() async => data;
}

class _Failing implements RemoteConfigSource {
  @override
  Future<Map<String, Object?>> fetch() async => throw Exception('offline');
}
