class SupplierTransaction {
  const SupplierTransaction({
    required this.id,
    required this.supplierId,
    required this.amountDelta,
    required this.type,
    required this.createdAt,
    this.referenceId,
    this.noteAr,
    this.createdBy,
  });

  final String id;
  final String supplierId;
  final double amountDelta;
  final SupplierTransactionType type;
  final DateTime createdAt;
  final String? referenceId;
  final String? noteAr;
  final String? createdBy;
}

enum SupplierTransactionType {
  purchaseDebtIncrease,
  payment,
  debtDecrease,
  settlement,
  adjustment,
}
