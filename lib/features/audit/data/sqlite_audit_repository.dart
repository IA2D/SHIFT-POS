import '../../../core/database/database_gateway.dart';
import '../../../core/database/database_tables.dart';
import '../domain/audit_event.dart';
import '../domain/audit_repository.dart';
import 'in_memory_audit_repository.dart';

class SqliteAuditRepository implements AuditRepository {
  SqliteAuditRepository(this._database);

  final DatabaseGateway _database;

  Future<void> initialize() async {
    if ((await _database.query(DatabaseTables.auditEvents)).isNotEmpty) return;
    final seed = InMemoryAuditRepository.seeded();
    for (final event in await seed.listEvents()) {
      await record(event);
    }
  }

  @override
  Future<List<AuditEvent>> listEvents() async {
    final rows = await _database.query(DatabaseTables.auditEvents);
    final events = rows.map(_eventFromRow).toList();
    events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return events;
  }

  @override
  Future<AuditEvent> record(AuditEvent event) async {
    await _database.save(DatabaseTables.auditEvents, event.id, {
      'action': event.action,
      'actorUsername': event.actorUsername,
      'actorId': event.actorId,
      'targetId': event.targetId,
      'targetType': event.targetType,
      'detailAr': event.detailAr,
      'metadata': event.metadata,
      'createdAt': event.createdAt.toIso8601String(),
    });
    return event;
  }

  AuditEvent _eventFromRow(Map<String, Object?> row) => AuditEvent(
        id: row['id']! as String,
        action: row['action']! as String,
        actorUsername: row['actorUsername']! as String,
        actorId: row['actorId'] as String?,
        targetId: row['targetId'] as String?,
        targetType: row['targetType'] as String?,
        detailAr: row['detailAr'] as String?,
        metadata: (row['metadata'] as Map<String, Object?>?) ?? const {},
        createdAt: DateTime.parse(row['createdAt']! as String),
      );
}
