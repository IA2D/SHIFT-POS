import 'cash_drawer_transaction.dart';

abstract interface class CashRepository {
  Future<List<CashDrawerTransaction>> listTransactions();

  Future<CashDrawerTransaction> saveTransaction(
    CashDrawerTransaction transaction,
  );
}
