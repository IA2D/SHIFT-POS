class CashDrawerTransaction {
  const CashDrawerTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.createdBy,
    required this.createdAt,
    this.shiftId,
    this.orderId,
    this.supplierId,
    this.noteAr,
  });

  final String id;
  final CashDrawerTransactionType type;
  final double amount;
  final String? shiftId;
  final String? orderId;
  final String? supplierId;
  final String? noteAr;
  final String createdBy;
  final DateTime createdAt;
}

enum CashDrawerTransactionType {
  sale,
  expense,
  supplierPayment,
  purchasePayment,
  cashIn,
  cashOut,
}
