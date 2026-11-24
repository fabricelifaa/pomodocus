import 'package:flutter/material.dart';

import '../../features/focus/domain/entities/session_type.dart';

/// Brand palette, derived from the Pomodocus logo.
abstract final class BrandColors {
  static const coral = Color(0xFFF2553D);
  static const teal = Color(0xFF23A58C);
  static const ink = Color(0xFF1E1F24);
  static const paper = Color(0xFFFBF7F3);
  static const night = Color(0xFF15171C);
}

/// Per-phase accent colors, available through `Theme.of(context)`.
@immutable
class PhaseColors extends ThemeExtension<PhaseColors> {
  const PhaseColors({
    required this.focus,
    required this.shortBreak,
    required this.longBreak,
    required this.track,
    required this.muted,
    required this.card,
  });

  final Color focus;
  final Color shortBreak;
  final Color longBreak;
  final Color track;
  final Color muted;
  final Color card;

  Color forType(SessionType t) => switch (t) {
    SessionType.focus => focus,
    SessionType.shortBreak => shortBreak,
    SessionType.longBreak => longBreak,
  };

  static const light = PhaseColors(
    focus: Color(0xFFE8492F),
    shortBreak: Color(0xFF1C9880),
    longBreak: Color(0xFF2F7F9E),
    track: Color(0xFFEDE6DF),
    muted: Color(0xFF6B6E78),
    card: Colors.white,
  );

  static const dark = PhaseColors(
    focus: Color(0xFFFF6B52),
    shortBreak: Color(0xFF3CC4A8),
    longBreak: Color(0xFF5BB0D0),
    track: Color(0xFF2A2D35),
    muted: Color(0xFFA3A6B0),
    card: Color(0xFF1E2027),
  );

  @override
  PhaseColors copyWith({
    Color? focus,
    Color? shortBreak,
    Color? longBreak,
    Color? track,
    Color? muted,
    Color? card,
  }) => PhaseColors(
    focus: focus ?? this.focus,
    shortBreak: shortBreak ?? this.shortBreak,
    longBreak: longBreak ?? this.longBreak,
    track: track ?? this.track,
    muted: muted ?? this.muted,
    card: card ?? this.card,
  );

  @override
  PhaseColors lerp(PhaseColors? other, double t) {
    if (other == null) return this;
    return PhaseColors(
      focus: Color.lerp(focus, other.focus, t)!,
      shortBreak: Color.lerp(shortBreak, other.shortBreak, t)!,
      longBreak: Color.lerp(longBreak, other.longBreak, t)!,
      track: Color.lerp(track, other.track, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      card: Color.lerp(card, other.card, t)!,
    );
  }
}

extension PhaseColorsX on BuildContext {
  PhaseColors get phase => Theme.of(this).extension<PhaseColors>()!;
}
