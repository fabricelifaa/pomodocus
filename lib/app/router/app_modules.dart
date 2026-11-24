import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/remote_config_service.dart';
import '../../features/about/presentation/about_screen.dart';
import '../../features/focus/presentation/screens/focus_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/statistics/presentation/statistics_screen.dart';

/// A top-level destination of the bottom navigation.
///
/// Extension point: a future module (tasks, habits…) registers one entry here
/// with its own routes and an optional remote [flag]. Disabled modules are
/// simply filtered out; Focus/Stats/Settings have no flag and are always
/// available as the local fallback navigation.
class AppModule {
  const AppModule({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
    this.flag,
    this.routes = const [],
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;
  final String? flag;
  final List<RouteBase> routes;
}

final List<AppModule> allModules = [
  AppModule(
    path: '/focus',
    label: 'Focus',
    icon: Icons.timer_outlined,
    selectedIcon: Icons.timer_rounded,
    builder: (_) => const FocusScreen(),
  ),
  AppModule(
    path: '/stats',
    label: 'Statistiques',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights_rounded,
    builder: (_) => const StatisticsScreen(),
  ),
  // Example of a future module behind a flag (not part of the MVP):
  // AppModule(path: '/tasks', label: 'Tâches', flag: 'feature_tasks_enabled', …),
  AppModule(
    path: '/settings',
    label: 'Paramètres',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
    builder: (_) => const SettingsScreen(),
    routes: [GoRoute(path: 'about', builder: (_, _) => const AboutScreen())],
  ),
];

List<AppModule> enabledModules(RemoteConfig config) => [
  for (final m in allModules)
    if (m.flag == null || config.isEnabled(m.flag!)) m,
];
