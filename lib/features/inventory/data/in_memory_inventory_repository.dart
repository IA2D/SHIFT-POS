// ignore_for_file: require_trailing_commas

import '../../../shared/domain/money.dart';
import '../domain/ingredient.dart';
import '../domain/inventory_repository.dart';
import '../domain/inventory_transaction.dart';

class InMemoryInventoryRepository implements InventoryRepository {
  InMemoryInventoryRepository({
    required List<Ingredient> ingredients,
    List<InventoryTransaction> transactions = const [],
  })  : _ingredients = [...ingredients],
        _transactions = [...transactions];

  factory InMemoryInventoryRepository.seeded() {
    final now = DateTime.now();
    return InMemoryInventoryRepository(
      ingredients: [
        Ingredient(
            id: 'meat',
            nameAr: 'لحم',
            unit: 'كجم',
            lowStockThreshold: 5,
            createdAt: now,
            updatedAt: now),
        Ingredient(
            id: 'chicken',
            nameAr: 'فراخ',
            unit: 'قطعة',
            lowStockThreshold: 10,
            createdAt: now,
            updatedAt: now),
        Ingredient(
            id: 'spices',
            nameAr: 'توابل',
            unit: 'كجم',
            lowStockThreshold: 1,
            createdAt: now,
            updatedAt: now),
      ],
      transactions: [
        InventoryTransaction(
          id: 'inv-seed-meat',
          ingredientId: 'meat',
          quantityDelta: 25,
          unit: 'كجم',
          type: InventoryTransactionType.purchase,
          createdAt: now,
          noteAr: 'رصيد افتتاحي',
          createdBy: 'system',
        ),
        InventoryTransaction(
          id: 'inv-seed-chicken',
          ingredientId: 'chicken',
          quantityDelta: 40,
          unit: 'قطعة',
          type: InventoryTransactionType.purchase,
          createdAt: now,
          noteAr: 'رصيد افتتاحي',
          createdBy: 'system',
        ),
      ],
    );
  }

  final List<Ingredient> _ingredients;
  final List<InventoryTransaction> _transactions;

  @override
  Future<List<Ingredient>> listIngredients() async {
    final ingredients = [..._ingredients];
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
    final index =
        _ingredients.indexWhere((current) => current.id == ingredient.id);
    if (index == -1) {
      _ingredients.add(next);
    } else {
      _ingredients[index] = next;
    }
    return next;
  }

  @override
  Future<void> deleteIngredient(String id) async {
    _ingredients.removeWhere((ingredient) => ingredient.id == id);
  }

  @override
  Future<List<InventoryTransaction>> listTransactions() async {
    final transactions = [..._transactions];
    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return transactions;
  }

  @override
  Future<InventoryTransaction> saveTransaction(
      InventoryTransaction transaction) async {
    final index =
        _transactions.indexWhere((current) => current.id == transaction.id);
    if (index == -1) {
      _transactions.add(transaction);
    } else {
      _transactions[index] = transaction;
    }
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
}
