import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/config/sentry_config.dart';
import 'core/providers.dart';
import 'core/services/display_mode_service.dart';
import 'core/services/home_integration_service.dart';
import 'core/services/notification_service.dart';

Future<void> bootstrap() async {
  if (!SentryConfig.enabled) return _start();
  // Started first so that errors during the launch are reported too.
  await SentryFlutter.init((o) {
    o.dsn = SentryConfig.dsn;
    o.environment = SentryConfig.environment;
    if (SentryConfig.release.isNotEmpty) o.release = SentryConfig.release;
    o.tracesSampleRate = SentryConfig.tracesSampleRate;
    // No personal data: no IP address, no user identifiers.
    o.sendDefaultPii = false;
  }, appRunner: _start);
}

Future<void> _start() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait app; the full-screen countdown switches to landscape itself.
  await SystemDisplayModeService().enterStandard();

  final prefs = await SharedPreferences.getInstance();
  final notifications = LocalNotificationService();
  // Init without asking for permission; never blocks the launch for long.
  await notifications.init().timeout(
    const Duration(seconds: 3),
    onTimeout: () {},
  );

  // Opened from the widget, the Quick Settings tile or a launcher shortcut?
  final home = PlatformHomeIntegrationService();
  final initialAction = await home.initialAction().timeout(
    const Duration(seconds: 1),
    onTimeout: () => null,
  );

  runApp(
    SentryWidget(
      child: ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          notificationServiceProvider.overrideWithValue(notifications),
          homeIntegrationProvider.overrideWithValue(home),
          initialLaunchActionProvider.overrideWithValue(initialAction),
        ],
        child: const PomodocusApp(),
      ),
    ),
  );
}
