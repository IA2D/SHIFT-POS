import '../../../core/database/database_gateway.dart';
import '../../../core/database/database_tables.dart';
import '../domain/supplier.dart';
import '../domain/supplier_repository.dart';
import '../domain/supplier_transaction.dart';
import 'in_memory_supplier_repository.dart';

class SqliteSupplierRepository implements SupplierRepository {
  SqliteSupplierRepository(this._database);

  final DatabaseGateway _database;

  Future<void> initialize() async {
    if ((await _database.query(DatabaseTables.suppliers)).isNotEmpty) return;
    final seed = InMemorySupplierRepository.seeded();
    for (final supplier in await seed.listSuppliers()) {
      await _saveSupplier(supplier);
    }
    for (final transaction in await seed.listTransactions()) {
      await saveTransaction(transaction);
    }
  }

  @override
  Future<List<Supplier>> listSuppliers() async {
    final rows = await _database.query(DatabaseTables.suppliers);
    final suppliers = rows.map(_supplierFromRow).toList();
    suppliers.sort((a, b) => a.nameAr.compareTo(b.nameAr));
    return suppliers;
  }

  @override
  Future<Supplier> saveSupplier(Supplier supplier) async {
    final now = DateTime.now();
    final next = supplier.copyWith(
      createdAt: supplier.createdAt ?? now,
      updatedAt: now,
    );
    await _saveSupplier(next);
    return next;
  }

  Future<void> _saveSupplier(Supplier supplier) {
    return _database.save(DatabaseTables.suppliers, supplier.id, {
      'nameAr': supplier.nameAr,
      'phone': supplier.phone,
      'noteAr': supplier.noteAr,
      'active': supplier.active,
      'createdAt': supplier.createdAt?.toIso8601String(),
      'updatedAt': supplier.updatedAt?.toIso8601String(),
    });
  }

  @override
  Future<void> deleteSupplier(String id) async {
    await _database.delete(DatabaseTables.suppliers, id);
  }

  @override
  Future<List<SupplierTransaction>> listTransactions() async {
    final rows = await _database.query(DatabaseTables.supplierTransactions);
    final transactions = rows.map(_transactionFromRow).toList();
    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return transactions;
  }

  @override
  Future<SupplierTransaction> saveTransaction(
    SupplierTransaction transaction,
  ) async {
    await _database.save(
      DatabaseTables.supplierTransactions,
      transaction.id,
      {
        'supplierId': transaction.supplierId,
        'amountDelta': transaction.amountDelta,
        'type': transaction.type.name,
        'createdAt': transaction.createdAt.toIso8601String(),
        'referenceId': transaction.referenceId,
        'noteAr': transaction.noteAr,
        'createdBy': transaction.createdBy,
      },
    );
    return transaction;
  }

  Supplier _supplierFromRow(Map<String, Object?> row) => Supplier(
        id: row['id']! as String,
        nameAr: row['nameAr']! as String,
        phone: row['phone'] as String?,
        noteAr: row['noteAr'] as String?,
        active: row['active'] as bool? ?? true,
        createdAt: _date(row['createdAt']),
        updatedAt: _date(row['updatedAt']),
      );

  SupplierTransaction _transactionFromRow(Map<String, Object?> row) =>
      SupplierTransaction(
        id: row['id']! as String,
        supplierId: row['supplierId']! as String,
        amountDelta: (row['amountDelta']! as num).toDouble(),
        type: SupplierTransactionType.values.byName(row['type']! as String),
        createdAt: DateTime.parse(row['createdAt']! as String),
        referenceId: row['referenceId'] as String?,
        noteAr: row['noteAr'] as String?,
        createdBy: row['createdBy'] as String?,
      );

  DateTime? _date(Object? value) =>
      value is String ? DateTime.parse(value) : null;
}
