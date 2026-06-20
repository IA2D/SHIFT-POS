import '../../../shared/domain/money.dart';
import '../domain/supplier_transaction.dart';

class SupplierBalanceService {
  const SupplierBalanceService();

  Map<String, double> balancesBySupplier(
    Iterable<SupplierTransaction> transactions,
  ) {
    final balances = <String, double>{};

    for (final transaction in transactions) {
      final current = balances[transaction.supplierId] ?? 0;
      balances[transaction.supplierId] = Money.round(
        current + transaction.amountDelta,
      );
    }

    return balances;
  }

  double balanceForSupplier(
    Iterable<SupplierTransaction> transactions,
    String supplierId,
  ) {
    return balancesBySupplier(transactions)[supplierId] ?? 0;
  }
}
