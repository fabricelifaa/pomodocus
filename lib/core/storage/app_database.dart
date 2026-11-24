import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// History of finished sessions. Dates are stored as UTC epoch millis.
@DataClassName('SessionRow')
class FocusSessions extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  IntColumn get startedAt => integer()();
  IntColumn get plannedDurationSeconds => integer()();
  IntColumn get endedAt => integer().nullable()();
  IntColumn get actualDurationSeconds => integer()();
  TextColumn get status => text()();
  IntColumn get cycleNumber => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [FocusSessions])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'pomodocus'));

  /// Bump this and add a step in [migration] for every schema change.
  /// Future modules (tasks, projects…) add their own tables here through
  /// versioned migrations.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_sessions_started ON focus_sessions (started_at)',
      );
    },
    onUpgrade: (m, from, to) async {
      // Example for v2:
      // if (from < 2) { await m.createTable(tasks); }
    },
  );
}
