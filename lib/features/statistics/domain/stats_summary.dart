import '../../focus/domain/entities/focus_session.dart';
import '../../focus/domain/entities/session_type.dart';

class DayStat {
  const DayStat(this.day, this.focusSeconds, this.completed);
  final DateTime day;
  final int focusSeconds;
  final int completed;
}

/// Basic statistics derived from local history.
///
/// Rules:
/// - "temps concentré" sums the real focused time of focus sessions
///   (completed ones plus the elapsed part of interrupted ones);
/// - "sessions terminées" only counts completed focus sessions;
/// - breaks never count as focus time.
class StatsSummary {
  const StatsSummary({
    required this.todayFocusSeconds,
    required this.todayCompleted,
    required this.todayInterrupted,
    required this.weekFocusSeconds,
    required this.days,
    required this.recent,
  });

  final int todayFocusSeconds;
  final int todayCompleted;
  final int todayInterrupted;
  final int weekFocusSeconds;

  /// Last 7 days, oldest first, today last.
  final List<DayStat> days;

  /// Most recent sessions first (focus and breaks).
  final List<FocusSession> recent;

  bool get isEmpty => recent.isEmpty;

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// First instant included in the 7-day window.
  static DateTime windowStart(DateTime now) =>
      startOfDay(now).subtract(const Duration(days: 6));

  factory StatsSummary.from(List<FocusSession> sessions, DateTime now) {
    final today = startOfDay(now);
    final days = List.generate(
      7,
      (i) => DateTime(today.year, today.month, today.day - 6 + i),
    );
    final secs = List.filled(7, 0);
    final done = List.filled(7, 0);
    var todayInterrupted = 0;

    for (final s in sessions) {
      if (s.type != SessionType.focus) continue;
      final d = startOfDay(s.startedAt);
      final idx = days.indexOf(d);
      if (idx < 0) continue;
      secs[idx] += s.actualDurationSeconds;
      if (s.isCompleted) {
        done[idx]++;
      } else if (idx == 6) {
        todayInterrupted++;
      }
    }

    final sorted = [...sessions]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    return StatsSummary(
      todayFocusSeconds: secs[6],
      todayCompleted: done[6],
      todayInterrupted: todayInterrupted,
      weekFocusSeconds: secs.fold(0, (a, b) => a + b),
      days: [for (var i = 0; i < 7; i++) DayStat(days[i], secs[i], done[i])],
      recent: sorted.take(30).toList(),
    );
  }
}
