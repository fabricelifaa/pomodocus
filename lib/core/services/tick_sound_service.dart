import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../features/settings/domain/pomodoro_settings.dart';

/// One short sound per second in the full-screen countdown.
abstract interface class TickSoundService {
  Future<void> tick(ClockStyle style);
  Future<void> dispose();
}

class AssetTickSoundService implements TickSoundService {
  AudioPlayer? _player;
  ClockStyle? _loaded;

  // Mixes with the user's music (no audio focus request), so a tick never
  // pauses a podcast or a playlist.
  static final _context = AudioContext(
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none,
      usageType: AndroidUsageType.media,
      contentType: AndroidContentType.sonification,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.ambient,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
  );

  static String _asset(ClockStyle s) => switch (s) {
    ClockStyle.digital => 'sounds/tick_digital.wav',
    ClockStyle.flip => 'sounds/tick_flip.wav',
  };

  @override
  Future<void> tick(ClockStyle style) async {
    try {
      var p = _player;
      if (p == null) {
        p = _player = AudioPlayer();
        await p.setAudioContext(_context);
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
      }
      if (_loaded != style) {
        await p.setSource(AssetSource(_asset(style)));
        _loaded = style;
      }
      await p.stop();
      await p.resume();
    } catch (e) {
      debugPrint('Tick failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    final p = _player;
    _player = null;
    _loaded = null;
    await p?.dispose();
  }
}

class NoopTickSoundService implements TickSoundService {
  final List<ClockStyle> ticks = [];

  @override
  Future<void> tick(ClockStyle style) async => ticks.add(style);

  @override
  Future<void> dispose() async {}
}
