import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/pomodoro_settings.dart';

class SettingsRepository {
  SettingsRepository(this._prefs);

  static const key = 'settings_v1';
  static const notificationPromptKey = 'notification_prompt_shown_v1';
  final SharedPreferences _prefs;

  PomodoroSettings load() {
    final raw = _prefs.getString(key);
    if (raw == null) return PomodoroSettings.defaults;
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, Object?>) return PomodoroSettings.fromJson(json);
    } catch (_) {}
    return PomodoroSettings.defaults;
  }

  Future<void> save(PomodoroSettings s) =>
      _prefs.setString(key, jsonEncode(s.validated().toJson()));

  bool get notificationPromptShown =>
      _prefs.getBool(notificationPromptKey) ?? false;

  Future<void> markNotificationPromptShown() =>
      _prefs.setBool(notificationPromptKey, true);
}
