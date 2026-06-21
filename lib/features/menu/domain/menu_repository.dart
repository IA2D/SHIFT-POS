import 'menu_category.dart';
import 'menu_item.dart';

abstract interface class MenuRepository {
  Future<List<MenuCategory>> listCategories();

  Future<MenuCategory> saveCategory(MenuCategory category);

  Future<void> deleteCategory(String id);

  Future<List<MenuItem>> listItems({bool includeInactive = false});

  Future<MenuItem> saveItem(MenuItem item);

  Future<void> deleteItem(String id);

  Future<List<ItemSize>> listSizes();

  Future<ItemSize> saveSize(ItemSize size);

  Future<void> deleteSize(String id);

  Future<List<ItemAddon>> listAddons();

  Future<ItemAddon> saveAddon(ItemAddon addon);

  Future<void> deleteAddon(String id);

  Future<List<Recipe>> listRecipes();

  Future<Recipe?> getRecipeForItem(String menuItemId);

  Future<Recipe> saveRecipe(Recipe recipe);
}
