class InventoryTransaction {
  const InventoryTransaction({
    required this.id,
    required this.ingredientId,
    required this.quantityDelta,
    required this.unit,
    required this.type,
    required this.createdAt,
    this.referenceId,
    this.noteAr,
    this.createdBy,
  });

  final String id;
  final String ingredientId;
  final double quantityDelta;
  final String unit;
  final InventoryTransactionType type;
  final DateTime createdAt;
  final String? referenceId;
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
