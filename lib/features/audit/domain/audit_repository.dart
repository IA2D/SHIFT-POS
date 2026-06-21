import 'audit_event.dart';

abstract interface class AuditRepository {
  Future<List<AuditEvent>> listEvents();

  Future<AuditEvent> record(AuditEvent event);
}
