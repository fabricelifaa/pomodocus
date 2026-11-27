import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/device_orientation_service.dart';
import '../../settings/presentation/settings_controller.dart';

/// Listens to how the phone is physically held while the app is in the
/// foreground and the "full screen when rotated" setting is on. The sensor is
/// released in the background and when the setting is off.
mixin RotationAware<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  StreamSubscription<PhysicalOrientation>? _rotation;
  AppLifecycleListener? _lifecycle;

  /// Called on each (debounced, distinct) orientation change.
  void onPhysicalOrientation(PhysicalOrientation o);

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: (_) => _syncRotation());
    ref.listenManual(
      settingsProvider.select(
        (s) => s.fullscreenEnabled && s.fullscreenOnRotate,
      ),
      (_, _) => _syncRotation(),
    );
    _syncRotation();
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _rotation?.cancel();
    super.dispose();
  }

  void _syncRotation() {
    if (!mounted) return;
    final s = ref.read(settingsProvider);
    final life = WidgetsBinding.instance.lifecycleState;
    final want =
        s.fullscreenEnabled &&
        s.fullscreenOnRotate &&
        (life == null || life == AppLifecycleState.resumed);
    if (want && _rotation == null) {
      _rotation = ref.read(deviceOrientationServiceProvider).watch().listen((
        o,
      ) {
        if (mounted) onPhysicalOrientation(o);
      });
    } else if (!want && _rotation != null) {
      _rotation!.cancel();
      _rotation = null;
    }
  }

  /// True when no dialog or bottom sheet covers this screen.
  bool get isTopmost {
    var popup = false;
    Navigator.of(context, rootNavigator: true).popUntil((r) {
      popup = r is PopupRoute;
      return true;
    });
    return !popup && (ModalRoute.of(context)?.isCurrent ?? true);
  }
}
