import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/active_timer_state.dart';
import '../domain/repositories/repositories.dart';

class PrefsActiveTimerRepository implements ActiveTimerRepository {
  PrefsActiveTimerRepository(this._prefs);

  static const key = 'active_timer_v1';
  final SharedPreferences _prefs;

  @override
  ActiveTimerState? load() {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?>) return null;
      return ActiveTimerState.tryFromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(ActiveTimerState state) =>
      _prefs.setString(key, jsonEncode(state.toJson()));

  @override
  Future<void> clear() => _prefs.remove(key);
}
