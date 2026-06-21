// ignore_for_file: require_trailing_commas

import 'ingredient.dart';
import 'inventory_transaction.dart';

abstract interface class InventoryRepository {
  Future<List<Ingredient>> listIngredients();

  Future<Ingredient> saveIngredient(Ingredient ingredient);

  Future<void> deleteIngredient(String id);

  Future<List<InventoryTransaction>> listTransactions();

  Future<InventoryTransaction> saveTransaction(
      InventoryTransaction transaction);

  Future<List<IngredientStock>> listStocks();
}
