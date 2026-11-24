import '../entities/active_timer_state.dart';
import '../entities/focus_session.dart';

/// History of finished sessions. Implementations must make [record]
/// idempotent: recording the same session id twice keeps a single row.
abstract interface class SessionRepository {
  Future<void> record(FocusSession session);

  Stream<List<FocusSession>> watchSince(DateTime since);

  Future<List<FocusSession>> since(DateTime since);
}

/// Persists the currently active timer so it survives app restarts.
abstract interface class ActiveTimerRepository {
  ActiveTimerState? load();

  Future<void> save(ActiveTimerState state);

  Future<void> clear();
}
