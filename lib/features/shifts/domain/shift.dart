class Shift {
  const Shift({
    required this.id,
    required this.cashierId,
    required this.cashierName,
    required this.status,
    required this.openedAt,
    required this.createdAt,
    required this.updatedAt,
    this.cashierCode,
    this.archived = false,
    this.openingCash,
    this.closedAt,
    this.closedBy,
    this.closingCash,
  });

  final String id;
  final String cashierId;
  final String cashierName;
  final String? cashierCode;
  final ShiftStatus status;
  final bool archived;
  final double? openingCash;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String? closedBy;
  final double? closingCash;
  final DateTime createdAt;
  final DateTime updatedAt;

  Shift copyWith({
    ShiftStatus? status,
    bool? archived,
    DateTime? closedAt,
    String? closedBy,
    double? closingCash,
    DateTime? updatedAt,
  }) {
    return Shift(
      id: id,
      cashierId: cashierId,
      cashierName: cashierName,
      cashierCode: cashierCode,
      status: status ?? this.status,
      archived: archived ?? this.archived,
      openingCash: openingCash,
      openedAt: openedAt,
      closedAt: closedAt ?? this.closedAt,
      closedBy: closedBy ?? this.closedBy,
      closingCash: closingCash ?? this.closingCash,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum ShiftStatus {
  open,
  closed,
}
