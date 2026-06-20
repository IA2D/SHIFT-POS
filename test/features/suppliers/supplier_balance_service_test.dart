import 'package:flutter_test/flutter_test.dart';
import 'package:shift_pos/features/suppliers/application/supplier_balance_service.dart';
import 'package:shift_pos/features/suppliers/domain/supplier_transaction.dart';

void main() {
  const service = SupplierBalanceService();

  test('calculates supplier debt from signed transactions', () {
    final now = DateTime.utc(2026, 6, 20);
    final balance = service.balanceForSupplier(
      [
        SupplierTransaction(
          id: 'purchase-1',
          supplierId: 'supplier-a',
          amountDelta: 1000,
          type: SupplierTransactionType.purchaseDebtIncrease,
          createdAt: now,
        ),
        SupplierTransaction(
          id: 'payment-1',
          supplierId: 'supplier-a',
          amountDelta: -350,
          type: SupplierTransactionType.payment,
          createdAt: now,
        ),
      ],
      'supplier-a',
    );

    expect(balance, 650);
  });

  test('keeps suppliers separated', () {
    final now = DateTime.utc(2026, 6, 20);
    final balances = service.balancesBySupplier([
      SupplierTransaction(
        id: 'a',
        supplierId: 'supplier-a',
        amountDelta: 100,
        type: SupplierTransactionType.purchaseDebtIncrease,
        createdAt: now,
      ),
      SupplierTransaction(
        id: 'b',
        supplierId: 'supplier-b',
        amountDelta: 75,
        type: SupplierTransactionType.purchaseDebtIncrease,
        createdAt: now,
      ),
    ]);

    expect(balances['supplier-a'], 100);
    expect(balances['supplier-b'], 75);
  });
}
