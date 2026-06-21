class InventoryTransaction {
  const InventoryTransaction({
    required this.id,
    required this.ingredientId,
    required this.quantityDelta,
    required this.unit,
    required this.type,
    required this.createdAt,
    this.ingredientNameAr,
    this.referenceType,
    this.referenceId,
    this.shiftId,
    this.supplierId,
    this.noteAr,
    this.createdBy,
  });

  final String id;
  final String ingredientId;
  final double quantityDelta;
  final String unit;
  final InventoryTransactionType type;
  final DateTime createdAt;
  final String? ingredientNameAr;
  final InventoryReferenceType? referenceType;
  final String? referenceId;
  final String? shiftId;
  final String? supplierId;
  final String? noteAr;
  final String? createdBy;
}

enum InventoryTransactionType {
  purchase,
  sale,
  saleReversal,
  waste,
  adjustment,
}

enum InventoryReferenceType {
  order,
  purchase,
  manual,
  shift,
  supplier,
}
