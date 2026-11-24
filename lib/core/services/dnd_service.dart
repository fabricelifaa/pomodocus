import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// "Ne pas déranger" while the full-screen countdown is shown.
///
/// Android needs the user to grant "Accès à Ne pas déranger" once (system
/// settings page). The native side saves the user's own DND state before
/// changing it and restores it afterwards, even if the app was killed.
abstract interface class DndService {
  Future<bool> hasAccess();

  /// Opens the system page where the user grants the access.
  Future<void> requestAccess();

  /// Blocks calls and message notifications (alarms and media still play).
  /// Returns false when the access is missing.
  Future<bool> enable();

  /// Restores the state the user had before [enable].
  Future<void> disable();
}

class PlatformDndService implements DndService {
  static const _channel = MethodChannel('com.fab2dev.pomodocus/dnd');

  Future<T?> _call<T>(String method) async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await _channel.invokeMethod<T>(method);
    } on PlatformException catch (e) {
      debugPrint('DND $method failed: $e');
    } on MissingPluginException {
      // Not available (tests, other platforms).
    }
    return null;
  }

  @override
  Future<bool> hasAccess() async => await _call<bool>('hasAccess') ?? false;

  @override
  Future<void> requestAccess() => _call<void>('requestAccess');

  @override
  Future<bool> enable() async => await _call<bool>('enable') ?? false;

  @override
  Future<void> disable() => _call<void>('disable');
}

class FakeDndService implements DndService {
  FakeDndService({this.access = true});

  bool access;
  bool active = false;
  int requests = 0;

  @override
  Future<bool> hasAccess() async => access;

  @override
  Future<void> requestAccess() async => requests++;

  @override
  Future<bool> enable() async {
    if (!access) return false;
    active = true;
    return true;
  }

  @override
  Future<void> disable() async => active = false;
}
