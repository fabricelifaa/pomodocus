import 'package:flutter_test/flutter_test.dart';
import 'package:pomodocus/features/focus/domain/entities/focus_session.dart';
import 'package:pomodocus/features/focus/domain/entities/session_type.dart';
import 'package:pomodocus/features/statistics/domain/stats_summary.dart';

FocusSession s(
  String id,
  DateTime start, {
  SessionType type = SessionType.focus,
  SessionStatus status = SessionStatus.completed,
  int secs = 1500,
}) => FocusSession(
  id: id,
  type: type,
  startedAt: start,
  plannedDurationSeconds: 1500,
  endedAt: start.add(Duration(seconds: secs)),
  actualDurationSeconds: secs,
  status: status,
  cycleNumber: 1,
);

void main() {
  final now = DateTime(2026, 11, 24, 18);

  test('empty history', () {
    final r = StatsSummary.from([], now);
    expect(r.isEmpty, isTrue);
    expect(r.days, hasLength(7));
    expect(r.todayFocusSeconds, 0);
  });

  test('today and 7-day totals, completed vs interrupted', () {
    final r = StatsSummary.from([
      s('1', DateTime(2026, 11, 24, 9)),
      s('2', DateTime(2026, 11, 24, 10)),
      s(
        '3',
        DateTime(2026, 11, 24, 11),
        status: SessionStatus.interrupted,
        secs: 600,
      ),
      s(
        '4',
        DateTime(2026, 11, 24, 11, 30),
        type: SessionType.shortBreak,
        secs: 300,
      ),
      s('5', DateTime(2026, 11, 20, 9)),
      s('6', DateTime(2026, 11, 17, 9)), // outside the window
    ], now);
    expect(r.todayCompleted, 2);
    expect(r.todayInterrupted, 1);
    expect(r.todayFocusSeconds, 1500 * 2 + 600);
    expect(r.weekFocusSeconds, 1500 * 3 + 600);
    expect(r.days.last.day, DateTime(2026, 11, 24));
    expect(r.days.first.day, DateTime(2026, 11, 18));
    expect(r.days[2].focusSeconds, 1500); // 20 Nov
    expect(r.recent.first.id, '4');
  });
}
