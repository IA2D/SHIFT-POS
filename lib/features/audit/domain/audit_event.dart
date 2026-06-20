class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.action,
    required this.actorUsername,
    required this.createdAt,
    this.actorId,
    this.targetId,
    this.targetType,
    this.detailAr,
    this.metadata = const {},
  });

  final String id;
  final String action;
  final String actorUsername;
  final DateTime createdAt;
  final String? actorId;
  final String? targetId;
  final String? targetType;
  final String? detailAr;
  final Map<String, Object?> metadata;
}
