import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodocus/core/providers.dart';
import 'package:pomodocus/core/services/device_orientation_service.dart';
import 'package:pomodocus/core/services/display_mode_service.dart';
import 'package:pomodocus/core/services/dnd_service.dart';
import 'package:pomodocus/core/services/feedback_services.dart';
import 'package:pomodocus/core/services/home_integration_service.dart';
import 'package:pomodocus/core/services/notification_service.dart';
import 'package:pomodocus/core/services/tick_sound_service.dart';
import 'package:pomodocus/core/services/update_service.dart';
import 'package:pomodocus/core/utils/clock.dart';
import 'package:pomodocus/features/focus/domain/entities/focus_session.dart';
import 'package:pomodocus/features/focus/domain/repositories/repositories.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InMemorySessionRepository implements SessionRepository {
  final Map<String, FocusSession> rows = {};
  final _changes = StreamController<void>.broadcast();
  int recordCalls = 0;

  @override
  Future<void> record(FocusSession s) async {
    recordCalls++;
    rows.putIfAbsent(s.id, () => s);
    _changes.add(null);
  }

  List<FocusSession> _since(DateTime d) =>
      rows.values.where((s) => !s.startedAt.isBefore(d)).toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  @override
  Future<List<FocusSession>> since(DateTime d) async => _since(d);

  @override
  Stream<List<FocusSession>> watchSince(DateTime d) async* {
    yield _since(d);
    await for (final _ in _changes.stream) {
      yield _since(d);
    }
  }
}

class FakeUpdateService implements UpdateService {
  @override
  Future<UpdateState> check() async => UpdateState.unavailable;
  @override
  Future<UpdateState> download() async => UpdateState.unavailable;
  @override
  Future<AppVersionInfo> versionInfo() async =>
      const AppVersionInfo(version: '1.0.0', buildNumber: '1');
}

class TestDeps {
  TestDeps(this.prefs, {DateTime? now})
    : clock = FakeClock(now ?? DateTime(2026, 11, 24, 9));

  final SharedPreferences prefs;
  final FakeClock clock;
  final sessions = InMemorySessionRepository();
  final notifications = NoopNotificationService();
  final sound = NoopSoundService();
  final display = NoopDisplayModeService();
  final orientation = FakeDeviceOrientationService();
  final ticks = NoopTickSoundService();
  final dnd = FakeDndService();
  final home = FakeHomeIntegrationService();

  /// Off by default so tests land directly on the Focus screen.
  bool splash = false;

  List get overrides => [
    sharedPreferencesProvider.overrideWithValue(prefs),
    clockProvider.overrideWithValue(clock),
    sessionRepositoryProvider.overrideWithValue(sessions),
    notificationServiceProvider.overrideWithValue(notifications),
    soundServiceProvider.overrideWithValue(sound),
    hapticsServiceProvider.overrideWithValue(NoopHapticsService()),
    updateServiceProvider.overrideWithValue(FakeUpdateService()),
    displayModeServiceProvider.overrideWithValue(display),
    deviceOrientationServiceProvider.overrideWithValue(orientation),
    tickSoundServiceProvider.overrideWithValue(ticks),
    dndServiceProvider.overrideWithValue(dnd),
    homeIntegrationProvider.overrideWithValue(home),
    initialLaunchActionProvider.overrideWithValue(home.initial),
    showSplashProvider.overrideWithValue(splash),
  ];

  ProviderContainer container() =>
      ProviderContainer(overrides: overrides.cast());
}
