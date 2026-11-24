import '../../focus/domain/entities/session_type.dart';

enum AppThemePreference {
  system,
  light,
  dark;

  static AppThemePreference fromName(String? n) => AppThemePreference.values
      .firstWhere((e) => e.name == n, orElse: () => AppThemePreference.system);
}

/// Look of the full-screen countdown.
enum ClockStyle {
  digital,
  flip;

  static ClockStyle fromName(String? n) => ClockStyle.values.firstWhere(
    (e) => e.name == n,
    orElse: () => ClockStyle.digital,
  );
}

/// Bounds used to validate every duration setting.
abstract final class SettingsBounds {
  static const focusMin = 1, focusMax = 120;
  static const shortMin = 1, shortMax = 30;
  static const longMin = 1, longMax = 60;
  static const intervalMin = 2, intervalMax = 10;
}

class PomodoroSettings {
  const PomodoroSettings({
    this.focusDurationMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.longBreakInterval = 4,
    this.autoStartBreaks = false,
    this.autoStartFocus = false,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.themeMode = AppThemePreference.system,
    this.fullscreenEnabled = true,
    this.fullscreenAutoOpen = false,
    this.fullscreenClockStyle = ClockStyle.digital,
    this.fullscreenTickSound = true,
    this.fullscreenDnd = true,
  });

  final int focusDurationMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int longBreakInterval;
  final bool autoStartBreaks;
  final bool autoStartFocus;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final AppThemePreference themeMode;

  /// Shows the landscape full-screen countdown ("mode vidéo").
  final bool fullscreenEnabled;

  /// Opens the full-screen countdown automatically when a session starts.
  final bool fullscreenAutoOpen;

  /// Digital digits or flip-clock cards in full screen.
  final ClockStyle fullscreenClockStyle;

  /// Plays a tick each second in full screen (sound matches the clock style).
  final bool fullscreenTickSound;

  /// Turns on Do Not Disturb (no calls, no messages) while in full screen.
  final bool fullscreenDnd;

  static const defaults = PomodoroSettings();

  int durationSecondsFor(SessionType type) => switch (type) {
    SessionType.focus => focusDurationMinutes * 60,
    SessionType.shortBreak => shortBreakMinutes * 60,
    SessionType.longBreak => longBreakMinutes * 60,
  };

  /// Returns a copy where every value is clamped to its valid bounds.
  PomodoroSettings validated() => copyWith(
    focusDurationMinutes: focusDurationMinutes.clamp(
      SettingsBounds.focusMin,
      SettingsBounds.focusMax,
    ),
    shortBreakMinutes: shortBreakMinutes.clamp(
      SettingsBounds.shortMin,
      SettingsBounds.shortMax,
    ),
    longBreakMinutes: longBreakMinutes.clamp(
      SettingsBounds.longMin,
      SettingsBounds.longMax,
    ),
    longBreakInterval: longBreakInterval.clamp(
      SettingsBounds.intervalMin,
      SettingsBounds.intervalMax,
    ),
  );

  PomodoroSettings copyWith({
    int? focusDurationMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? longBreakInterval,
    bool? autoStartBreaks,
    bool? autoStartFocus,
    bool? soundEnabled,
    bool? vibrationEnabled,
    AppThemePreference? themeMode,
    bool? fullscreenEnabled,
    bool? fullscreenAutoOpen,
    ClockStyle? fullscreenClockStyle,
    bool? fullscreenTickSound,
    bool? fullscreenDnd,
  }) => PomodoroSettings(
    focusDurationMinutes: focusDurationMinutes ?? this.focusDurationMinutes,
    shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
    longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
    longBreakInterval: longBreakInterval ?? this.longBreakInterval,
    autoStartBreaks: autoStartBreaks ?? this.autoStartBreaks,
    autoStartFocus: autoStartFocus ?? this.autoStartFocus,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    themeMode: themeMode ?? this.themeMode,
    fullscreenEnabled: fullscreenEnabled ?? this.fullscreenEnabled,
    fullscreenAutoOpen: fullscreenAutoOpen ?? this.fullscreenAutoOpen,
    fullscreenClockStyle: fullscreenClockStyle ?? this.fullscreenClockStyle,
    fullscreenTickSound: fullscreenTickSound ?? this.fullscreenTickSound,
    fullscreenDnd: fullscreenDnd ?? this.fullscreenDnd,
  );

  Map<String, Object?> toJson() => {
    'focusDurationMinutes': focusDurationMinutes,
    'shortBreakMinutes': shortBreakMinutes,
    'longBreakMinutes': longBreakMinutes,
    'longBreakInterval': longBreakInterval,
    'autoStartBreaks': autoStartBreaks,
    'autoStartFocus': autoStartFocus,
    'soundEnabled': soundEnabled,
    'vibrationEnabled': vibrationEnabled,
    'themeMode': themeMode.name,
    'fullscreenEnabled': fullscreenEnabled,
    'fullscreenAutoOpen': fullscreenAutoOpen,
    'fullscreenClockStyle': fullscreenClockStyle.name,
    'fullscreenTickSound': fullscreenTickSound,
    'fullscreenDnd': fullscreenDnd,
  };

  factory PomodoroSettings.fromJson(Map<String, Object?> j) {
    int i(String k, int d) => (j[k] as num?)?.toInt() ?? d;
    bool b(String k, bool d) => j[k] is bool ? j[k]! as bool : d;
    const d = PomodoroSettings.defaults;
    return PomodoroSettings(
      focusDurationMinutes: i('focusDurationMinutes', d.focusDurationMinutes),
      shortBreakMinutes: i('shortBreakMinutes', d.shortBreakMinutes),
      longBreakMinutes: i('longBreakMinutes', d.longBreakMinutes),
      longBreakInterval: i('longBreakInterval', d.longBreakInterval),
      autoStartBreaks: b('autoStartBreaks', d.autoStartBreaks),
      autoStartFocus: b('autoStartFocus', d.autoStartFocus),
      soundEnabled: b('soundEnabled', d.soundEnabled),
      vibrationEnabled: b('vibrationEnabled', d.vibrationEnabled),
      themeMode: AppThemePreference.fromName(j['themeMode'] as String?),
      fullscreenEnabled: b('fullscreenEnabled', d.fullscreenEnabled),
      fullscreenAutoOpen: b('fullscreenAutoOpen', d.fullscreenAutoOpen),
      fullscreenClockStyle: ClockStyle.fromName(
        j['fullscreenClockStyle'] as String?,
      ),
      fullscreenTickSound: b('fullscreenTickSound', d.fullscreenTickSound),
      fullscreenDnd: b('fullscreenDnd', d.fullscreenDnd),
    ).validated();
  }

  @override
  bool operator ==(Object other) =>
      other is PomodoroSettings &&
      other.toJson().toString() == toJson().toString();

  @override
  int get hashCode => toJson().toString().hashCode;
}
