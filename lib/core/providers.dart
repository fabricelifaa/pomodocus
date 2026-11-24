import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../features/focus/data/drift_session_repository.dart';
import '../features/focus/data/prefs_active_timer_repository.dart';
import '../features/focus/domain/pomodoro_engine.dart';
import '../features/focus/domain/repositories/repositories.dart';
import '../features/settings/data/settings_repository.dart';
import 'config/remote_config_service.dart';
import 'services/display_mode_service.dart';
import 'services/dnd_service.dart';
import 'services/feedback_services.dart';
import 'services/home_integration_service.dart';
import 'services/tick_sound_service.dart';
import 'services/notification_service.dart';
import 'services/update_service.dart';
import 'storage/app_database.dart';
import 'utils/clock.dart';

/// Overridden in bootstrap with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final engineProvider = Provider<PomodoroEngine>((ref) {
  const uuid = Uuid();
  return PomodoroEngine(clock: ref.watch(clockProvider), newId: uuid.v4);
});

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => DriftSessionRepository(ref.watch(databaseProvider)),
);

final activeTimerRepositoryProvider = Provider<ActiveTimerRepository>(
  (ref) => PrefsActiveTimerRepository(ref.watch(sharedPreferencesProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => LocalNotificationService(),
);

final soundServiceProvider = Provider<SoundService>(
  (ref) => AssetSoundService(),
);

final hapticsServiceProvider = Provider<HapticsService>(
  (ref) => SystemHapticsService(),
);

final displayModeServiceProvider = Provider<DisplayModeService>(
  (ref) => SystemDisplayModeService(),
);

final tickSoundServiceProvider = Provider<TickSoundService>((ref) {
  final s = AssetTickSoundService();
  ref.onDispose(s.dispose);
  return s;
});

final dndServiceProvider = Provider<DndService>((ref) => PlatformDndService());

final homeIntegrationProvider = Provider<HomeIntegrationService>(
  (ref) => PlatformHomeIntegrationService(),
);

/// Action that launched the app (widget, tile, shortcut), read in bootstrap.
final initialLaunchActionProvider = Provider<LaunchAction?>((ref) => null);

/// Animated splash at launch. Skipped when the app is opened from a widget,
/// a tile or a shortcut: the user wants the timer right away.
final showSplashProvider = Provider<bool>(
  (ref) => ref.watch(initialLaunchActionProvider) == null,
);

final updateServiceProvider = Provider<UpdateService>(
  (ref) => ShorebirdUpdateService(),
);

final remoteConfigServiceProvider = Provider<RemoteConfigService>(
  (ref) => RemoteConfigService(prefs: ref.watch(sharedPreferencesProvider)),
);

/// Current remote config: cached value first, refreshed in the background.
final remoteConfigProvider =
    NotifierProvider<RemoteConfigNotifier, RemoteConfig>(
      RemoteConfigNotifier.new,
    );

class RemoteConfigNotifier extends Notifier<RemoteConfig> {
  @override
  RemoteConfig build() {
    final service = ref.watch(remoteConfigServiceProvider);
    Future.microtask(() async {
      final fresh = await service.refresh();
      if (ref.mounted) state = fresh;
    });
    return service.cached;
  }
}
