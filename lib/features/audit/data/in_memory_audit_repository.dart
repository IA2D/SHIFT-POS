import '../domain/audit_event.dart';
import '../domain/audit_repository.dart';

class InMemoryAuditRepository implements AuditRepository {
  InMemoryAuditRepository({List<AuditEvent> events = const []})
      : _events = [...events];

  factory InMemoryAuditRepository.seeded() {
    return InMemoryAuditRepository(
      events: [
        AuditEvent(
          id: 'audit-start',
          action: 'login',
          actorUsername: 'system',
          createdAt: DateTime.now(),
          detailAr: 'بدء جلسة Flutter محلية',
        ),
      ],
    );
  }

  final List<AuditEvent> _events;

  @override
  Future<List<AuditEvent>> listEvents() async {
    final events = [..._events];
    events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return events;
  }

  @override
  Future<AuditEvent> record(AuditEvent event) async {
    _events.insert(0, event);
    return event;
  }
}
