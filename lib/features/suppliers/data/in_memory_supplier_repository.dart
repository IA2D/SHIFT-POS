// ignore_for_file: require_trailing_commas

import '../domain/supplier.dart';
import '../domain/supplier_repository.dart';
import '../domain/supplier_transaction.dart';

class InMemorySupplierRepository implements SupplierRepository {
  InMemorySupplierRepository({
    required List<Supplier> suppliers,
    List<SupplierTransaction> transactions = const [],
  })  : _suppliers = [...suppliers],
        _transactions = [...transactions];

  factory InMemorySupplierRepository.seeded() {
    final now = DateTime.now();
    return InMemorySupplierRepository(
      suppliers: [
        Supplier(
            id: 'sup-meat',
            nameAr: 'مورد اللحوم',
            phone: '01000000000',
            createdAt: now,
            updatedAt: now),
        Supplier(
            id: 'sup-drinks',
            nameAr: 'مورد المشروبات',
            phone: '01100000000',
            createdAt: now,
            updatedAt: now),
      ],
      transactions: [
        SupplierTransaction(
          id: 'st1',
          supplierId: 'sup-meat',
          amountDelta: 2400,
          type: SupplierTransactionType.purchaseDebtIncrease,
          createdAt: now,
          createdBy: 'system',
          noteAr: 'فاتورة افتتاحية',
        ),
      ],
    );
  }

  final List<Supplier> _suppliers;
  final List<SupplierTransaction> _transactions;

  @override
  Future<List<Supplier>> listSuppliers() async {
    final suppliers = [..._suppliers];
    suppliers.sort((a, b) => a.nameAr.compareTo(b.nameAr));
    return suppliers;
  }

  @override
  Future<Supplier> saveSupplier(Supplier supplier) async {
    final now = DateTime.now();
    final next =
        supplier.copyWith(createdAt: supplier.createdAt ?? now, updatedAt: now);
    final index = _suppliers.indexWhere((current) => current.id == supplier.id);
    if (index == -1) {
      _suppliers.add(next);
    } else {
      _suppliers[index] = next;
    }
    return next;
  }

  @override
  Future<void> deleteSupplier(String id) async {
    _suppliers.removeWhere((supplier) => supplier.id == id);
  }

  @override
  Future<List<SupplierTransaction>> listTransactions() async {
    final transactions = [..._transactions];
    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return transactions;
  }

  @override
  Future<SupplierTransaction> saveTransaction(
      SupplierTransaction transaction) async {
    final index =
        _transactions.indexWhere((current) => current.id == transaction.id);
    if (index == -1) {
      _transactions.add(transaction);
    } else {
      _transactions[index] = transaction;
    }
    return transaction;
  }
}
