import '../../../core/database/database_gateway.dart';
import '../../../core/database/database_tables.dart';
import '../domain/cash_drawer_transaction.dart';
import '../domain/cash_repository.dart';

class SqliteCashRepository implements CashRepository {
  SqliteCashRepository(this._database);

  final DatabaseGateway _database;

  @override
  Future<List<CashDrawerTransaction>> listTransactions() async {
    final transactions = (await _database
            .query(DatabaseTables.cashDrawerTransactions))
        .map(_fromRow)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return transactions;
  }

  @override
  Future<CashDrawerTransaction> saveTransaction(
    CashDrawerTransaction transaction,
  ) async {
    await _database.save(
      DatabaseTables.cashDrawerTransactions,
      transaction.id,
      {
        'type': transaction.type.name,
        'amount': transaction.amount,
        'shiftId': transaction.shiftId,
        'orderId': transaction.orderId,
        'supplierId': transaction.supplierId,
        'noteAr': transaction.noteAr,
        'createdBy': transaction.createdBy,
        'createdAt': transaction.createdAt.toIso8601String(),
      },
    );
    return transaction;
  }

  CashDrawerTransaction _fromRow(Map<String, Object?> row) =>
      CashDrawerTransaction(
        id: row['id']! as String,
        type: CashDrawerTransactionType.values.byName(row['type']! as String),
        amount: (row['amount']! as num).toDouble(),
        shiftId: row['shiftId'] as String?,
        orderId: row['orderId'] as String?,
        supplierId: row['supplierId'] as String?,
        noteAr: row['noteAr'] as String?,
        createdBy: row['createdBy']! as String,
        createdAt: DateTime.parse(row['createdAt']! as String),
      );
}
