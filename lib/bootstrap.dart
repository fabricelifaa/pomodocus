import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/providers.dart';
import 'core/services/display_mode_service.dart';
import 'core/services/home_integration_service.dart';
import 'core/services/notification_service.dart';

Future<void> bootstrap() async {
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
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationServiceProvider.overrideWithValue(notifications),
        homeIntegrationProvider.overrideWithValue(home),
        initialLaunchActionProvider.overrideWithValue(initialAction),
      ],
      child: const PomodocusApp(),
    ),
  );
}
