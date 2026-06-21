// ignore_for_file: require_trailing_commas

import '../../../core/database/database_gateway.dart';
import '../../../core/database/database_tables.dart';
import '../../../shared/domain/money.dart';
import '../domain/ingredient.dart';
import '../domain/inventory_repository.dart';
import '../domain/inventory_transaction.dart';
import 'in_memory_inventory_repository.dart';

class SqliteInventoryRepository implements InventoryRepository {
  SqliteInventoryRepository(this._database);

  final DatabaseGateway _database;

  Future<void> initialize() async {
    if ((await _database.query(DatabaseTables.ingredients)).isNotEmpty) return;
    final seed = InMemoryInventoryRepository.seeded();
    for (final ingredient in await seed.listIngredients()) {
      await _saveIngredient(ingredient);
    }
    for (final transaction in await seed.listTransactions()) {
      await saveTransaction(transaction);
    }
  }

  @override
  Future<List<Ingredient>> listIngredients() async {
    final rows = await _database.query(DatabaseTables.ingredients);
    final ingredients = rows.map(_ingredientFromRow).toList();
    ingredients.sort((a, b) => a.nameAr.compareTo(b.nameAr));
    return ingredients;
  }

  @override
  Future<Ingredient> saveIngredient(Ingredient ingredient) async {
    final now = DateTime.now();
    final next = ingredient.copyWith(
      createdAt: ingredient.createdAt ?? now,
      updatedAt: now,
    );
    await _saveIngredient(next);
    return next;
  }

  Future<void> _saveIngredient(Ingredient ingredient) {
    return _database.save(DatabaseTables.ingredients, ingredient.id, {
      'nameAr': ingredient.nameAr,
      'unit': ingredient.unit,
      'lowStockThreshold': ingredient.lowStockThreshold,
      'active': ingredient.active,
      'createdAt': ingredient.createdAt?.toIso8601String(),
      'updatedAt': ingredient.updatedAt?.toIso8601String(),
    });
  }

  @override
  Future<void> deleteIngredient(String id) async {
    await _database.delete(DatabaseTables.ingredients, id);
  }

  @override
  Future<List<InventoryTransaction>> listTransactions() async {
    final rows = await _database.query(DatabaseTables.inventoryTransactions);
    final transactions = rows.map(_transactionFromRow).toList();
    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return transactions;
  }

  @override
  Future<InventoryTransaction> saveTransaction(
      InventoryTransaction transaction) async {
    await _database.save(
      DatabaseTables.inventoryTransactions,
      transaction.id,
      {
        'ingredientId': transaction.ingredientId,
        'ingredientNameAr': transaction.ingredientNameAr,
        'quantityDelta': transaction.quantityDelta,
        'unit': transaction.unit,
        'type': transaction.type.name,
        'referenceType': transaction.referenceType?.name,
        'referenceId': transaction.referenceId,
        'shiftId': transaction.shiftId,
        'supplierId': transaction.supplierId,
        'createdAt': transaction.createdAt.toIso8601String(),
        'noteAr': transaction.noteAr,
        'createdBy': transaction.createdBy,
      },
    );
    return transaction;
  }

  @override
  Future<List<IngredientStock>> listStocks() async {
    final ingredients = await listIngredients();
    final transactions = await listTransactions();
    return ingredients.map((ingredient) {
      final quantity = transactions
          .where((transaction) => transaction.ingredientId == ingredient.id)
          .fold<double>(
              0, (sum, transaction) => sum + transaction.quantityDelta);
      return IngredientStock(
        ingredientId: ingredient.id,
        nameAr: ingredient.nameAr,
        unit: ingredient.unit,
        quantity: Money.round(quantity),
        lowStockThreshold: ingredient.lowStockThreshold,
      );
    }).toList(growable: false);
  }

  Ingredient _ingredientFromRow(Map<String, Object?> row) => Ingredient(
        id: row['id']! as String,
        nameAr: row['nameAr']! as String,
        unit: row['unit']! as String,
        lowStockThreshold: (row['lowStockThreshold'] as num?)?.toDouble(),
        active: row['active'] as bool? ?? true,
        createdAt: _date(row['createdAt']),
        updatedAt: _date(row['updatedAt']),
      );

  InventoryTransaction _transactionFromRow(Map<String, Object?> row) {
    final referenceType = row['referenceType'] as String?;
    return InventoryTransaction(
      id: row['id']! as String,
      ingredientId: row['ingredientId']! as String,
      ingredientNameAr: row['ingredientNameAr'] as String?,
      quantityDelta: (row['quantityDelta']! as num).toDouble(),
      unit: row['unit']! as String,
      type: InventoryTransactionType.values.byName(row['type']! as String),
      referenceType: referenceType == null
          ? null
          : InventoryReferenceType.values.byName(referenceType),
      referenceId: row['referenceId'] as String?,
      shiftId: row['shiftId'] as String?,
      supplierId: row['supplierId'] as String?,
      createdAt: DateTime.parse(row['createdAt']! as String),
      noteAr: row['noteAr'] as String?,
      createdBy: row['createdBy'] as String?,
    );
  }

  DateTime? _date(Object? value) =>
      value is String ? DateTime.parse(value) : null;
}
