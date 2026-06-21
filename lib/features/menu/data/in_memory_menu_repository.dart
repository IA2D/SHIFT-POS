// ignore_for_file: require_trailing_commas

import '../domain/menu_category.dart';
import '../domain/menu_item.dart';
import '../domain/menu_repository.dart';

class InMemoryMenuRepository implements MenuRepository {
  InMemoryMenuRepository({
    required List<MenuCategory> categories,
    required List<MenuItem> items,
    List<ItemSize> sizes = const [],
    List<ItemAddon> addons = const [],
    List<Recipe> recipes = const [],
  })  : _categories = [...categories],
        _items = [...items],
        _sizes = [...sizes],
        _addons = [...addons],
        _recipes = [...recipes];

  factory InMemoryMenuRepository.seeded() {
    final now = DateTime.now();
    return InMemoryMenuRepository(
      categories: [
        MenuCategory(
            id: 'grills',
            nameAr: 'مشويات',
            sortOrder: 1,
            createdAt: now,
            updatedAt: now),
        MenuCategory(
            id: 'drinks',
            nameAr: 'مشروبات',
            sortOrder: 2,
            createdAt: now,
            updatedAt: now),
        MenuCategory(
            id: 'extras',
            nameAr: 'إضافات',
            sortOrder: 3,
            createdAt: now,
            updatedAt: now),
      ],
      sizes: const [
        ItemSize(id: 'small', nameAr: 'صغير', sortOrder: 1),
        ItemSize(id: 'medium', nameAr: 'وسط', sortOrder: 2),
        ItemSize(id: 'large', nameAr: 'كبير', sortOrder: 3),
      ],
      addons: const [
        ItemAddon(
            id: 'extra-cheese',
            nameAr: 'جبنة إضافية',
            defaultPrice: 15,
            sortOrder: 1),
        ItemAddon(
            id: 'extra-sauce',
            nameAr: 'صوص إضافي',
            defaultPrice: 10,
            sortOrder: 2),
      ],
      items: [
        MenuItem(
          id: 'grilled-chicken',
          categoryId: 'grills',
          nameAr: 'فراخ مشوية',
          price: 200,
          recipeId: 'recipe-grilled-chicken',
          sortOrder: 1,
          createdAt: now,
          updatedAt: now,
          sizeOptions: const [
            MenuItemSizeOption(
                id: 'chicken-half',
                masterSizeId: 'medium',
                labelAr: 'نصف',
                price: 120),
            MenuItemSizeOption(
                id: 'chicken-full',
                masterSizeId: 'large',
                labelAr: 'كامل',
                price: 200),
          ],
        ),
        MenuItem(
          id: 'kofta',
          categoryId: 'grills',
          nameAr: 'كفتة',
          price: 180,
          recipeId: 'recipe-kofta',
          sortOrder: 2,
          createdAt: now,
          updatedAt: now,
          isWeighted: true,
          weightedPriceOptions: const [
            WeightedPriceOption(
                id: 'kofta-kg', label: '1 كجم', weightKg: 1, price: 360),
            WeightedPriceOption(
                id: 'kofta-half', label: 'نصف كجم', weightKg: 0.5, price: 180),
          ],
          allowCustomWeight: true,
          customWeightUnitPrice: 360,
        ),
        MenuItem(
            id: 'rice',
            categoryId: 'extras',
            nameAr: 'أرز',
            price: 35,
            sortOrder: 1,
            createdAt: now,
            updatedAt: now),
        MenuItem(
            id: 'salad',
            categoryId: 'extras',
            nameAr: 'سلطة',
            price: 25,
            sortOrder: 2,
            createdAt: now,
            updatedAt: now),
        MenuItem(
            id: 'cola',
            categoryId: 'drinks',
            nameAr: 'كولا',
            price: 25,
            productType: ProductType.readyMade,
            sortOrder: 1,
            createdAt: now,
            updatedAt: now),
      ],
      recipes: const [
        Recipe(
          id: 'recipe-kofta',
          menuItemId: 'kofta',
          nameAr: 'وصفة الكفتة',
          basisQuantity: 1,
          basisUnit: 'كجم',
          lines: [
            RecipeLine(ingredientId: 'meat', quantity: 1, unit: 'كجم'),
            RecipeLine(ingredientId: 'spices', quantity: 0.05, unit: 'كجم'),
          ],
        ),
        Recipe(
          id: 'recipe-grilled-chicken',
          menuItemId: 'grilled-chicken',
          nameAr: 'وصفة الفراخ المشوية',
          basisQuantity: 1,
          basisUnit: 'وجبة',
          lines: [
            RecipeLine(ingredientId: 'chicken', quantity: 1, unit: 'قطعة'),
          ],
        ),
      ],
    );
  }

  final List<MenuCategory> _categories;
  final List<MenuItem> _items;
  final List<ItemSize> _sizes;
  final List<ItemAddon> _addons;
  final List<Recipe> _recipes;

  @override
  Future<List<MenuCategory>> listCategories() async {
    final categories = [..._categories];
    categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return categories;
  }

  @override
  Future<MenuCategory> saveCategory(MenuCategory category) async {
    final next = category.copyWith(
      updatedAt: DateTime.now(),
      createdAt: category.createdAt ?? DateTime.now(),
    );
    final index =
        _categories.indexWhere((current) => current.id == category.id);
    if (index == -1) {
      _categories.add(next);
    } else {
      _categories[index] = next;
    }
    return next;
  }

  @override
  Future<void> deleteCategory(String id) async {
    _categories.removeWhere((category) => category.id == id);
  }

  @override
  Future<List<MenuItem>> listItems({bool includeInactive = false}) async {
    final items = [
      ..._items.where((item) => includeInactive || item.active),
    ];
    items.sort((a, b) {
      final categoryCompare = a.categoryId.compareTo(b.categoryId);
      if (categoryCompare != 0) return categoryCompare;
      return a.sortOrder.compareTo(b.sortOrder);
    });
    return items;
  }

  @override
  Future<MenuItem> saveItem(MenuItem item) async {
    final now = DateTime.now();
    final next = item.copyWith(
      createdAt: item.createdAt ?? now,
      updatedAt: now,
      recipeId: item.recipeId.isEmpty ? 'recipe-${item.id}' : item.recipeId,
    );
    final index = _items.indexWhere((current) => current.id == item.id);
    if (index == -1) {
      _items.add(next);
    } else {
      _items[index] = next;
    }
    return next;
  }

  @override
  Future<void> deleteItem(String id) async {
    _items.removeWhere((item) => item.id == id);
    _recipes.removeWhere((recipe) => recipe.menuItemId == id);
  }

  @override
  Future<List<ItemSize>> listSizes() async {
    final sizes = [..._sizes];
    sizes.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sizes;
  }

  @override
  Future<ItemSize> saveSize(ItemSize size) async {
    final index = _sizes.indexWhere((current) => current.id == size.id);
    if (index == -1) {
      _sizes.add(size);
    } else {
      _sizes[index] = size;
    }
    return size;
  }

  @override
  Future<void> deleteSize(String id) async {
    _sizes.removeWhere((size) => size.id == id);
  }

  @override
  Future<List<ItemAddon>> listAddons() async {
    final addons = [..._addons];
    addons.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return addons;
  }

  @override
  Future<ItemAddon> saveAddon(ItemAddon addon) async {
    final index = _addons.indexWhere((current) => current.id == addon.id);
    if (index == -1) {
      _addons.add(addon);
    } else {
      _addons[index] = addon;
    }
    return addon;
  }

  @override
  Future<void> deleteAddon(String id) async {
    _addons.removeWhere((addon) => addon.id == id);
  }

  @override
  Future<List<Recipe>> listRecipes() async {
    return [..._recipes];
  }

  @override
  Future<Recipe?> getRecipeForItem(String menuItemId) async {
    for (final recipe in _recipes) {
      if (recipe.menuItemId == menuItemId) return recipe;
    }
    return null;
  }

  @override
  Future<Recipe> saveRecipe(Recipe recipe) async {
    final index = _recipes.indexWhere((current) => current.id == recipe.id);
    if (index == -1) {
      _recipes.add(recipe);
    } else {
      _recipes[index] = recipe;
    }
    return recipe;
  }
}
