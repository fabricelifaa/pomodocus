import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/entities/focus_session.dart';
import '../domain/entities/session_type.dart';
import '../domain/repositories/repositories.dart';

class DriftSessionRepository implements SessionRepository {
  DriftSessionRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> record(FocusSession s) async {
    // insertOrIgnore on the primary key makes recording idempotent.
    await _db
        .into(_db.focusSessions)
        .insert(
          FocusSessionsCompanion.insert(
            id: s.id,
            type: s.type.name,
            startedAt: s.startedAt.toUtc().millisecondsSinceEpoch,
            plannedDurationSeconds: s.plannedDurationSeconds,
            endedAt: Value(s.endedAt?.toUtc().millisecondsSinceEpoch),
            actualDurationSeconds: s.actualDurationSeconds,
            status: s.status.name,
            cycleNumber: s.cycleNumber,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  SimpleSelectStatement<$FocusSessionsTable, SessionRow> _query(
    DateTime since,
  ) {
    final ms = since.toUtc().millisecondsSinceEpoch;
    return _db.select(_db.focusSessions)
      ..where((t) => t.startedAt.isBiggerOrEqualValue(ms))
      ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]);
  }

  @override
  Stream<List<FocusSession>> watchSince(DateTime since) =>
      _query(since).watch().map((rows) => rows.map(_map).toList());

  @override
  Future<List<FocusSession>> since(DateTime since) async =>
      (await _query(since).get()).map(_map).toList();

  static FocusSession _map(SessionRow r) => FocusSession(
    id: r.id,
    type: SessionType.fromName(r.type),
    startedAt: DateTime.fromMillisecondsSinceEpoch(r.startedAt),
    plannedDurationSeconds: r.plannedDurationSeconds,
    endedAt: r.endedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(r.endedAt!),
    actualDurationSeconds: r.actualDurationSeconds,
    status: SessionStatus.fromName(r.status),
    cycleNumber: r.cycleNumber,
  );
}
