import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Typed, validated remote configuration. Flags are NOT a security mechanism:
/// they only show or hide features that ship in the binary.
@immutable
class RemoteConfig {
  const RemoteConfig({
    this.featureTasksEnabled = false,
    this.featureProjectsEnabled = false,
    this.featureHabitsEnabled = false,
    this.featureAdvancedStatsEnabled = false,
    this.maintenanceMode = false,
    this.minimumSupportedVersion,
    this.recommendedVersion,
    this.announcementMessage,
  });

  final bool featureTasksEnabled;
  final bool featureProjectsEnabled;
  final bool featureHabitsEnabled;
  final bool featureAdvancedStatsEnabled;
  final bool maintenanceMode;
  final String? minimumSupportedVersion;
  final String? recommendedVersion;
  final String? announcementMessage;

  /// Built-in defaults used when nothing valid was ever fetched.
  static const defaults = RemoteConfig();

  /// Parses untrusted input; any invalid field falls back to its default.
  factory RemoteConfig.fromJson(Map<String, Object?> j) {
    bool b(String k) => j[k] is bool && j[k]! as bool;
    String? v(String k) {
      final x = j[k];
      if (x is! String) return null;
      return RegExp(r'^\d+(\.\d+){0,2}$').hasMatch(x) ? x : null;
    }

    final msg = j['announcement_message'];
    return RemoteConfig(
      featureTasksEnabled: b('feature_tasks_enabled'),
      featureProjectsEnabled: b('feature_projects_enabled'),
      featureHabitsEnabled: b('feature_habits_enabled'),
      featureAdvancedStatsEnabled: b('feature_advanced_stats_enabled'),
      maintenanceMode: b('maintenance_mode'),
      minimumSupportedVersion: v('minimum_supported_version'),
      recommendedVersion: v('recommended_version'),
      announcementMessage: msg is String && msg.trim().isNotEmpty
          ? (msg.length > 280 ? msg.substring(0, 280) : msg)
          : null,
    );
  }

  Map<String, Object?> toJson() => {
    'feature_tasks_enabled': featureTasksEnabled,
    'feature_projects_enabled': featureProjectsEnabled,
    'feature_habits_enabled': featureHabitsEnabled,
    'feature_advanced_stats_enabled': featureAdvancedStatsEnabled,
    'maintenance_mode': maintenanceMode,
    'minimum_supported_version': minimumSupportedVersion,
    'recommended_version': recommendedVersion,
    'announcement_message': announcementMessage,
  };

  bool isEnabled(String flag) => toJson()[flag] == true;
}

/// Provider-agnostic source (HTTP endpoint, Firebase, Supabase…). Plug a real
/// implementation in later without touching the rest of the app.
abstract interface class RemoteConfigSource {
  Future<Map<String, Object?>> fetch();
}

/// Default source for the MVP: no backend, nothing to fetch.
class NoRemoteConfigSource implements RemoteConfigSource {
  const NoRemoteConfigSource();
  @override
  Future<Map<String, Object?>> fetch() async => const {};
}

class RemoteConfigService {
  RemoteConfigService({
    required SharedPreferences prefs,
    RemoteConfigSource source = const NoRemoteConfigSource(),
    this.timeout = const Duration(seconds: 5),
  }) : _prefs = prefs, // ignore: prefer_initializing_formals
       _source = source; // ignore: prefer_initializing_formals

  static const cacheKey = 'remote_config_cache_v1';
  final SharedPreferences _prefs;
  final RemoteConfigSource _source;
  final Duration timeout;

  /// Last valid config from cache, or built-in defaults. Synchronous so the
  /// app never waits on the network to start.
  RemoteConfig get cached {
    final raw = _prefs.getString(cacheKey);
    if (raw == null) return RemoteConfig.defaults;
    try {
      final j = jsonDecode(raw);
      if (j is Map<String, Object?>) return RemoteConfig.fromJson(j);
    } catch (_) {}
    return RemoteConfig.defaults;
  }

  /// Fetches in the background; on any error, keeps the cached value.
  Future<RemoteConfig> refresh() async {
    try {
      final data = await _source.fetch().timeout(timeout);
      if (data.isEmpty) return cached;
      final config = RemoteConfig.fromJson(data);
      await _prefs.setString(cacheKey, jsonEncode(config.toJson()));
      return config;
    } catch (e) {
      debugPrint('Remote config unavailable: $e');
      return cached;
    }
  }
}
