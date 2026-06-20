import '../../../shared/domain/money.dart';
import '../domain/inventory_transaction.dart';

class InventoryBalanceService {
  const InventoryBalanceService();

  Map<String, double> balancesByIngredient(
    Iterable<InventoryTransaction> transactions,
  ) {
    final balances = <String, double>{};

    for (final transaction in transactions) {
      final current = balances[transaction.ingredientId] ?? 0;
      balances[transaction.ingredientId] = Money.round(
        current + transaction.quantityDelta,
      );
    }

    return balances;
  }

  double balanceForIngredient(
    Iterable<InventoryTransaction> transactions,
    String ingredientId,
  ) {
    return balancesByIngredient(transactions)[ingredientId] ?? 0;
  }
}
