import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/services/home_integration_service.dart';
import '../features/focus/presentation/controllers/timer_controller.dart';
import '../features/focus/presentation/screens/fullscreen_timer_screen.dart';
import '../features/settings/domain/pomodoro_settings.dart';
import '../features/settings/presentation/settings_controller.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class PomodocusApp extends ConsumerStatefulWidget {
  const PomodocusApp({super.key});

  @override
  ConsumerState<PomodocusApp> createState() => _PomodocusAppState();
}

class _PomodocusAppState extends ConsumerState<PomodocusApp> {
  StreamSubscription<LaunchAction>? _actions;

  @override
  void initState() {
    super.initState();
    _actions = ref.read(homeIntegrationProvider).actions.listen(handleAction);
    final initial = ref.read(initialLaunchActionProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _publish();
      if (initial != null) handleAction(initial);
    });
  }

  @override
  void dispose() {
    _actions?.cancel();
    super.dispose();
  }

  /// Keeps the home-screen widget and the Quick Settings tile up to date.
  /// Only on state changes: the widget counts down by itself.
  void _publish() {
    final v = ref.read(timerControllerProvider);
    ref
        .read(homeIntegrationProvider)
        .publishTimer(v.timer, remainingSeconds: v.remainingSeconds);
  }

  /// Widget, tile or launcher shortcut.
  Future<void> handleAction(LaunchAction a) async {
    final router = ref.read(routerProvider);
    final ctl = ref.read(timerControllerProvider.notifier);
    String path() => router.routerDelegate.currentConfiguration.uri.path;

    Future<void> startOrResume() async {
      final t = ref.read(timerControllerProvider).timer;
      if (t.isIdle) {
        await ctl.start();
      } else if (t.isPaused) {
        await ctl.resume();
      }
    }

    switch (a) {
      case LaunchAction.start:
        if (path() != FullscreenTimerScreen.path) router.go('/focus');
        await startOrResume();
      case LaunchAction.fullscreen:
        if (path() != FullscreenTimerScreen.path) router.go('/focus');
        await startOrResume();
        // The Focus screen may already have opened it (auto-open setting).
        await WidgetsBinding.instance.endOfFrame;
        final enabled = ref.read(settingsProvider).fullscreenEnabled;
        if (enabled && path() != FullscreenTimerScreen.path) {
          router.push(FullscreenTimerScreen.path);
        }
      case LaunchAction.stats:
        router.go('/stats');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(timerControllerProvider.select((v) => v.timer), (_, _) {
      _publish();
    });
    final themePref = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp.router(
      title: 'Pomodocus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (themePref) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      },
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
