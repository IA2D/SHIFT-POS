import 'supplier.dart';
import 'supplier_transaction.dart';

abstract interface class SupplierRepository {
  Future<List<Supplier>> listSuppliers();

  Future<Supplier> saveSupplier(Supplier supplier);

  Future<void> deleteSupplier(String id);

  Future<List<SupplierTransaction>> listTransactions();

  Future<SupplierTransaction> saveTransaction(SupplierTransaction transaction);
}
