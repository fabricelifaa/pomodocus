import 'session_type.dart';

/// A finished (completed or interrupted) session stored in history.
class FocusSession {
  const FocusSession({
    required this.id,
    required this.type,
    required this.startedAt,
    required this.plannedDurationSeconds,
    required this.endedAt,
    required this.actualDurationSeconds,
    required this.status,
    required this.cycleNumber,
  });

  final String id;
  final SessionType type;
  final DateTime startedAt;
  final int plannedDurationSeconds;
  final DateTime? endedAt;
  final int actualDurationSeconds;
  final SessionStatus status;
  final int cycleNumber;

  bool get isCompleted => status == SessionStatus.completed;

  @override
  bool operator ==(Object other) =>
      other is FocusSession &&
      other.id == id &&
      other.type == type &&
      other.startedAt == startedAt &&
      other.plannedDurationSeconds == plannedDurationSeconds &&
      other.endedAt == endedAt &&
      other.actualDurationSeconds == actualDurationSeconds &&
      other.status == status &&
      other.cycleNumber == cycleNumber;

  @override
  int get hashCode => Object.hash(
    id,
    type,
    startedAt,
    plannedDurationSeconds,
    endedAt,
    actualDurationSeconds,
    status,
    cycleNumber,
  );

  @override
  String toString() =>
      'FocusSession($id, $type, $status, ${actualDurationSeconds}s, cycle $cycleNumber)';
}
