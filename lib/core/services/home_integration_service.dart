import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/focus/domain/entities/active_timer_state.dart';
import '../../features/focus/domain/entities/session_type.dart';

/// What the user asked for from outside the app: home-screen widget, Quick
/// Settings tile or a launcher shortcut (long press on the icon).
enum LaunchAction {
  /// Start (or resume) the focus timer.
  start,

  /// Start if needed and open the full-screen countdown.
  fullscreen,

  /// Show the statistics.
  stats;

  static LaunchAction? fromName(String? n) =>
      LaunchAction.values.where((e) => e.name == n).firstOrNull;
}

/// Bridge with the Android home screen: launch actions in, timer state out
/// (so the widget and the tile show the live countdown).
abstract interface class HomeIntegrationService {
  /// Action that launched the app, consumed once.
  Future<LaunchAction?> initialAction();

  /// Actions received while the app is already running.
  Stream<LaunchAction> get actions;

  Future<void> publishTimer(
    ActiveTimerState t, {
    required int remainingSeconds,
  });

  /// Asks the launcher to pin the widget. False when unsupported.
  Future<bool> requestPinWidget();

  /// Asks the system to add the Quick Settings tile (Android 13+).
  Future<bool> requestAddTile();
}

class PlatformHomeIntegrationService implements HomeIntegrationService {
  PlatformHomeIntegrationService() {
    if (_android) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'action') {
          final a = LaunchAction.fromName(call.arguments as String?);
          if (a != null) _actions.add(a);
        }
      });
    }
  }

  static const _channel = MethodChannel('com.fab2dev.pomodocus/home');
  final _actions = StreamController<LaunchAction>.broadcast();

  bool get _android => defaultTargetPlatform == TargetPlatform.android;

  Future<T?> _call<T>(String method, [Object? args]) async {
    if (!_android) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      debugPrint('Home $method failed: $e');
    } on MissingPluginException {
      // Not available (tests, other platforms).
    }
    return null;
  }

  @override
  Future<LaunchAction?> initialAction() async =>
      LaunchAction.fromName(await _call<String>('initialAction'));

  @override
  Stream<LaunchAction> get actions => _actions.stream;

  @override
  Future<void> publishTimer(
    ActiveTimerState t, {
    required int remainingSeconds,
  }) => _call<void>('publishTimer', {
    'status': t.status.name,
    'label': _label(t.type),
    'type': t.type.name,
    'endsAt': t.endsAt?.millisecondsSinceEpoch,
    'remainingSeconds': remainingSeconds,
  });

  static String _label(SessionType t) => switch (t) {
    SessionType.focus => 'Concentration',
    SessionType.shortBreak => 'Petite pause',
    SessionType.longBreak => 'Longue pause',
  };

  @override
  Future<bool> requestPinWidget() async =>
      await _call<bool>('requestPinWidget') ?? false;

  @override
  Future<bool> requestAddTile() async =>
      await _call<bool>('requestAddTile') ?? false;
}

class FakeHomeIntegrationService implements HomeIntegrationService {
  FakeHomeIntegrationService({this.initial});

  LaunchAction? initial;
  final controller = StreamController<LaunchAction>.broadcast();
  final List<(TimerStatus, int)> published = [];

  @override
  Future<LaunchAction?> initialAction() async {
    final a = initial;
    initial = null;
    return a;
  }

  @override
  Stream<LaunchAction> get actions => controller.stream;

  @override
  Future<void> publishTimer(
    ActiveTimerState t, {
    required int remainingSeconds,
  }) async => published.add((t.status, remainingSeconds));

  @override
  Future<bool> requestPinWidget() async => true;

  @override
  Future<bool> requestAddTile() async => true;
}
