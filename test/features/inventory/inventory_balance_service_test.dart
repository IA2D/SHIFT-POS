import 'package:flutter_test/flutter_test.dart';
import 'package:shift_pos/features/inventory/application/inventory_balance_service.dart';
import 'package:shift_pos/features/inventory/domain/inventory_transaction.dart';

void main() {
  const service = InventoryBalanceService();

  test('calculates ingredient balance from signed transactions', () {
    final now = DateTime.utc(2026, 6, 20);
    final balance = service.balanceForIngredient(
      [
        InventoryTransaction(
          id: 'p1',
          ingredientId: 'flour',
          quantityDelta: 10,
          unit: 'kg',
          type: InventoryTransactionType.purchase,
          createdAt: now,
        ),
        InventoryTransaction(
          id: 's1',
          ingredientId: 'flour',
          quantityDelta: -2.25,
          unit: 'kg',
          type: InventoryTransactionType.sale,
          createdAt: now,
        ),
        InventoryTransaction(
          id: 'r1',
          ingredientId: 'flour',
          quantityDelta: 0.25,
          unit: 'kg',
          type: InventoryTransactionType.saleReversal,
          createdAt: now,
        ),
      ],
      'flour',
    );

    expect(balance, 8);
  });

  test('groups balances by ingredient', () {
    final now = DateTime.utc(2026, 6, 20);
    final balances = service.balancesByIngredient([
      InventoryTransaction(
        id: 'p1',
        ingredientId: 'flour',
        quantityDelta: 10,
        unit: 'kg',
        type: InventoryTransactionType.purchase,
        createdAt: now,
      ),
      InventoryTransaction(
        id: 'p2',
        ingredientId: 'cheese',
        quantityDelta: 5,
        unit: 'kg',
        type: InventoryTransactionType.purchase,
        createdAt: now,
      ),
    ]);

    expect(balances['flour'], 10);
    expect(balances['cheese'], 5);
  });
}
