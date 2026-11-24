import 'session_type.dart';

enum TimerStatus {
  idle,
  running,
  paused;

  static TimerStatus fromName(String? name) => TimerStatus.values.firstWhere(
    (e) => e.name == name,
    orElse: () => TimerStatus.idle,
  );
}

/// Persisted state of the current timer. Remaining time is always derived
/// from timestamps (never from a tick counter).
class ActiveTimerState {
  const ActiveTimerState({
    required this.sessionId,
    required this.type,
    required this.status,
    required this.plannedDurationSeconds,
    required this.cycleNumber,
    this.startedAt,
    this.endsAt,
    this.remainingSecondsAtPause,
  });

  final String sessionId;
  final SessionType type;
  final TimerStatus status;

  /// First time the session was started (kept across pause/resume).
  final DateTime? startedAt;

  /// Theoretical end, only set while running.
  final DateTime? endsAt;

  /// Remaining seconds frozen while paused.
  final int? remainingSecondsAtPause;
  final int plannedDurationSeconds;

  /// Index of the focus pomodoro in the current set (1..longBreakInterval).
  final int cycleNumber;

  bool get isIdle => status == TimerStatus.idle;
  bool get isRunning => status == TimerStatus.running;
  bool get isPaused => status == TimerStatus.paused;

  ActiveTimerState copyWith({
    String? sessionId,
    SessionType? type,
    TimerStatus? status,
    DateTime? startedAt,
    DateTime? endsAt,
    int? remainingSecondsAtPause,
    int? plannedDurationSeconds,
    int? cycleNumber,
    bool clearEndsAt = false,
    bool clearRemaining = false,
    bool clearStartedAt = false,
  }) {
    return ActiveTimerState(
      sessionId: sessionId ?? this.sessionId,
      type: type ?? this.type,
      status: status ?? this.status,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      endsAt: clearEndsAt ? null : (endsAt ?? this.endsAt),
      remainingSecondsAtPause: clearRemaining
          ? null
          : (remainingSecondsAtPause ?? this.remainingSecondsAtPause),
      plannedDurationSeconds:
          plannedDurationSeconds ?? this.plannedDurationSeconds,
      cycleNumber: cycleNumber ?? this.cycleNumber,
    );
  }

  Map<String, Object?> toJson() => {
    'sessionId': sessionId,
    'type': type.name,
    'status': status.name,
    'startedAt': startedAt?.toUtc().toIso8601String(),
    'endsAt': endsAt?.toUtc().toIso8601String(),
    'remainingSecondsAtPause': remainingSecondsAtPause,
    'plannedDurationSeconds': plannedDurationSeconds,
    'cycleNumber': cycleNumber,
  };

  static ActiveTimerState? tryFromJson(Map<String, Object?> json) {
    try {
      final id = json['sessionId'] as String?;
      final planned = (json['plannedDurationSeconds'] as num?)?.toInt();
      final cycle = (json['cycleNumber'] as num?)?.toInt();
      if (id == null || planned == null || planned <= 0 || cycle == null) {
        return null;
      }
      DateTime? parse(Object? v) =>
          v is String ? DateTime.tryParse(v)?.toLocal() : null;
      final state = ActiveTimerState(
        sessionId: id,
        type: SessionType.fromName(json['type'] as String?),
        status: TimerStatus.fromName(json['status'] as String?),
        startedAt: parse(json['startedAt']),
        endsAt: parse(json['endsAt']),
        remainingSecondsAtPause: (json['remainingSecondsAtPause'] as num?)
            ?.toInt(),
        plannedDurationSeconds: planned,
        cycleNumber: cycle < 1 ? 1 : cycle,
      );
      // Reject inconsistent combinations rather than crash later.
      if (state.isRunning &&
          (state.endsAt == null || state.startedAt == null)) {
        return null;
      }
      if (state.isPaused && state.remainingSecondsAtPause == null) return null;
      return state;
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ActiveTimerState &&
      other.sessionId == sessionId &&
      other.type == type &&
      other.status == status &&
      other.startedAt == startedAt &&
      other.endsAt == endsAt &&
      other.remainingSecondsAtPause == remainingSecondsAtPause &&
      other.plannedDurationSeconds == plannedDurationSeconds &&
      other.cycleNumber == cycleNumber;

  @override
  int get hashCode => Object.hash(
    sessionId,
    type,
    status,
    startedAt,
    endsAt,
    remainingSecondsAtPause,
    plannedDurationSeconds,
    cycleNumber,
  );

  @override
  String toString() =>
      'ActiveTimerState($type, $status, cycle $cycleNumber, ends $endsAt, paused $remainingSecondsAtPause)';
}
