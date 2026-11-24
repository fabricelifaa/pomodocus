import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract interface class SoundService {
  Future<void> playSessionEnd();
}

abstract interface class HapticsService {
  Future<void> tap();
  Future<void> sessionEnd();
}

class AssetSoundService implements SoundService {
  AudioPlayer? _player;

  @override
  Future<void> playSessionEnd() async {
    try {
      final p = _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      await p.play(AssetSource('sounds/chime.wav'), volume: 0.8);
    } catch (e) {
      debugPrint('Sound failed: $e');
    }
  }
}

class SystemHapticsService implements HapticsService {
  @override
  Future<void> tap() => HapticFeedback.selectionClick();

  @override
  Future<void> sessionEnd() async {
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 140));
    await HapticFeedback.mediumImpact();
  }
}

class NoopSoundService implements SoundService {
  int plays = 0;
  @override
  Future<void> playSessionEnd() async => plays++;
}

class NoopHapticsService implements HapticsService {
  @override
  Future<void> tap() async {}
  @override
  Future<void> sessionEnd() async {}
}
