import '../domain/cash_drawer_transaction.dart';
import '../domain/cash_repository.dart';

class InMemoryCashRepository implements CashRepository {
  InMemoryCashRepository({List<CashDrawerTransaction> transactions = const []})
      : _transactions = [...transactions];

  final List<CashDrawerTransaction> _transactions;

  @override
  Future<List<CashDrawerTransaction>> listTransactions() async {
    final transactions = [..._transactions]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return transactions;
  }

  @override
  Future<CashDrawerTransaction> saveTransaction(
    CashDrawerTransaction transaction,
  ) async {
    final index =
        _transactions.indexWhere((value) => value.id == transaction.id);
    if (index < 0) {
      _transactions.add(transaction);
    } else {
      _transactions[index] = transaction;
    }
    return transaction;
  }
}
