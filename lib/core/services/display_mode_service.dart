import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Controls orientation, system bars and screen wake for the "video"
/// full-screen countdown. Abstract so that widgets stay testable.
abstract interface class DisplayModeService {
  /// Default app mode: portrait, edge-to-edge, normal screen timeout.
  Future<void> enterStandard();

  /// Landscape, system bars hidden (immersive), screen kept on.
  Future<void> enterFullscreenLandscape();
}

class SystemDisplayModeService implements DisplayModeService {
  @override
  Future<void> enterStandard() async {
    try {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('enterStandard failed: $e');
    }
  }

  @override
  Future<void> enterFullscreenLandscape() async {
    try {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      // Sticky: a swipe from the edge shows the bars briefly, then they hide.
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('enterFullscreenLandscape failed: $e');
    }
  }
}

class NoopDisplayModeService implements DisplayModeService {
  bool fullscreen = false;

  @override
  Future<void> enterStandard() async => fullscreen = false;

  @override
  Future<void> enterFullscreenLandscape() async => fullscreen = true;
}
