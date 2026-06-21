import '../../../core/database/database_gateway.dart';
import '../../../core/database/database_tables.dart';
import '../domain/menu_category.dart';
import '../domain/menu_item.dart';
import '../domain/menu_repository.dart';
import 'in_memory_menu_repository.dart';

class SqliteMenuRepository implements MenuRepository {
  SqliteMenuRepository(this._database);

  final DatabaseGateway _database;

  Future<void> initialize() async {
    if ((await _database.query(DatabaseTables.menuCategories)).isNotEmpty) {
      return;
    }
    final seed = InMemoryMenuRepository.seeded();
    for (final category in await seed.listCategories()) {
      await _saveCategory(category);
    }
    for (final size in await seed.listSizes()) {
      await saveSize(size);
    }
    for (final addon in await seed.listAddons()) {
      await saveAddon(addon);
    }
    for (final item in await seed.listItems(includeInactive: true)) {
      await _saveItem(item);
    }
    for (final recipe in await seed.listRecipes()) {
      await saveRecipe(recipe);
    }
  }

  @override
  Future<List<MenuCategory>> listCategories() async {
    final categories = (await _database.query(DatabaseTables.menuCategories))
        .map(_categoryFromRow)
        .toList();
    categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return categories;
  }

  @override
  Future<MenuCategory> saveCategory(MenuCategory category) async {
    final now = DateTime.now();
    final next = category.copyWith(
      createdAt: category.createdAt ?? now,
      updatedAt: now,
    );
    await _saveCategory(next);
    return next;
  }

  Future<void> _saveCategory(MenuCategory category) {
    return _database.save(DatabaseTables.menuCategories, category.id, {
      'nameAr': category.nameAr,
      'parentId': category.parentId,
      'sortOrder': category.sortOrder,
      'active': category.active,
      'createdAt': category.createdAt?.toIso8601String(),
      'updatedAt': category.updatedAt?.toIso8601String(),
    });
  }

  @override
  Future<void> deleteCategory(String id) async {
    final hasItems = (await listItems(includeInactive: true))
        .any((item) => item.categoryId == id);
    if (hasItems) throw StateError('Category contains menu items');
    await _database.delete(DatabaseTables.menuCategories, id);
  }

  @override
  Future<List<MenuItem>> listItems({bool includeInactive = false}) async {
    final items = (await _database.query(DatabaseTables.menuItems))
        .map(_itemFromRow)
        .where((item) => includeInactive || item.active)
        .toList();
    items.sort((a, b) {
      final category = a.categoryId.compareTo(b.categoryId);
      return category != 0 ? category : a.sortOrder.compareTo(b.sortOrder);
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
    await _saveItem(next);
    return next;
  }

  Future<void> _saveItem(MenuItem item) {
    return _database.save(DatabaseTables.menuItems, item.id, {
      'categoryId': item.categoryId,
      'nameAr': item.nameAr,
      'descriptionAr': item.descriptionAr,
      'price': item.price,
      'itemType': item.itemType.name,
      'productType': item.productType.name,
      'linkedIngredientId': item.linkedIngredientId,
      'sizeOptions': item.sizeOptions.map(_sizeOptionToRow).toList(),
      'attachments': item.attachments.map(_attachmentToRow).toList(),
      'isWeighted': item.isWeighted,
      'weightedPriceOptions':
          item.weightedPriceOptions.map(_weightedOptionToRow).toList(),
      'allowCustomWeight': item.allowCustomWeight,
      'customWeightUnitPrice': item.customWeightUnitPrice,
      'kitchenPrinterIds': item.kitchenPrinterIds,
      'imageUrl': item.imageUrl,
      'active': item.active,
      'recipeId': item.recipeId,
      'sortOrder': item.sortOrder,
      'createdAt': item.createdAt?.toIso8601String(),
      'updatedAt': item.updatedAt?.toIso8601String(),
    });
  }

  @override
  Future<void> deleteItem(String id) async {
    final recipes = await listRecipes();
    for (final recipe in recipes.where((value) => value.menuItemId == id)) {
      await _database.delete(DatabaseTables.recipes, recipe.id);
    }
    await _database.delete(DatabaseTables.menuItems, id);
  }

  @override
  Future<List<ItemSize>> listSizes() async {
    final sizes = (await _database.query(DatabaseTables.itemSizes))
        .map(_sizeFromRow)
        .toList();
    sizes.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sizes;
  }

  @override
  Future<ItemSize> saveSize(ItemSize size) async {
    await _database.save(DatabaseTables.itemSizes, size.id, {
      'nameAr': size.nameAr,
      'sortOrder': size.sortOrder,
      'active': size.active,
    });
    return size;
  }

  @override
  Future<void> deleteSize(String id) async {
    await _database.delete(DatabaseTables.itemSizes, id);
  }

  @override
  Future<List<ItemAddon>> listAddons() async {
    final addons = (await _database.query(DatabaseTables.itemAddons))
        .map(_addonFromRow)
        .toList();
    addons.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return addons;
  }

  @override
  Future<ItemAddon> saveAddon(ItemAddon addon) async {
    await _database.save(DatabaseTables.itemAddons, addon.id, {
      'nameAr': addon.nameAr,
      'defaultPrice': addon.defaultPrice,
      'sortOrder': addon.sortOrder,
      'active': addon.active,
    });
    return addon;
  }

  @override
  Future<void> deleteAddon(String id) async {
    await _database.delete(DatabaseTables.itemAddons, id);
  }

  @override
  Future<List<Recipe>> listRecipes() async {
    return (await _database.query(DatabaseTables.recipes))
        .map(_recipeFromRow)
        .toList();
  }

  @override
  Future<Recipe?> getRecipeForItem(String menuItemId) async {
    final rows = await _database.query(
      DatabaseTables.recipes,
      filters: {'menuItemId': menuItemId},
    );
    return rows.isEmpty ? null : _recipeFromRow(rows.first);
  }

  @override
  Future<Recipe> saveRecipe(Recipe recipe) async {
    await _database.save(DatabaseTables.recipes, recipe.id, {
      'menuItemId': recipe.menuItemId,
      'nameAr': recipe.nameAr,
      'basisQuantity': recipe.basisQuantity,
      'basisUnit': recipe.basisUnit,
      'lines': recipe.lines
          .map(
            (line) => {
              'ingredientId': line.ingredientId,
              'quantity': line.quantity,
              'unit': line.unit,
            },
          )
          .toList(),
    });
    return recipe;
  }

  MenuCategory _categoryFromRow(Map<String, Object?> row) => MenuCategory(
        id: row['id']! as String,
        nameAr: row['nameAr']! as String,
        parentId: row['parentId'] as String?,
        sortOrder: row['sortOrder'] as int? ?? 0,
        active: row['active'] as bool? ?? true,
        createdAt: _date(row['createdAt']),
        updatedAt: _date(row['updatedAt']),
      );

  MenuItem _itemFromRow(Map<String, Object?> row) => MenuItem(
        id: row['id']! as String,
        categoryId: row['categoryId']! as String,
        nameAr: row['nameAr']! as String,
        descriptionAr: row['descriptionAr'] as String?,
        price: (row['price']! as num).toDouble(),
        itemType: MenuItemType.values.byName(row['itemType']! as String),
        productType: ProductType.values.byName(row['productType']! as String),
        linkedIngredientId: row['linkedIngredientId'] as String?,
        sizeOptions:
            _mapList(row['sizeOptions']).map(_sizeOptionFromRow).toList(),
        attachments:
            _mapList(row['attachments']).map(_attachmentFromRow).toList(),
        isWeighted: row['isWeighted'] as bool? ?? false,
        weightedPriceOptions: _mapList(row['weightedPriceOptions'])
            .map(_weightedOptionFromRow)
            .toList(),
        allowCustomWeight: row['allowCustomWeight'] as bool? ?? false,
        customWeightUnitPrice:
            (row['customWeightUnitPrice'] as num?)?.toDouble(),
        kitchenPrinterIds:
            (row['kitchenPrinterIds'] as List<Object?>? ?? const [])
                .whereType<String>()
                .toList(),
        imageUrl: row['imageUrl'] as String?,
        active: row['active'] as bool? ?? true,
        recipeId: row['recipeId'] as String? ?? '',
        sortOrder: row['sortOrder'] as int? ?? 0,
        createdAt: _date(row['createdAt']),
        updatedAt: _date(row['updatedAt']),
      );

  ItemSize _sizeFromRow(Map<String, Object?> row) => ItemSize(
        id: row['id']! as String,
        nameAr: row['nameAr']! as String,
        sortOrder: row['sortOrder'] as int? ?? 0,
        active: row['active'] as bool? ?? true,
      );

  ItemAddon _addonFromRow(Map<String, Object?> row) => ItemAddon(
        id: row['id']! as String,
        nameAr: row['nameAr']! as String,
        defaultPrice: (row['defaultPrice']! as num).toDouble(),
        sortOrder: row['sortOrder'] as int? ?? 0,
        active: row['active'] as bool? ?? true,
      );

  Recipe _recipeFromRow(Map<String, Object?> row) => Recipe(
        id: row['id']! as String,
        menuItemId: row['menuItemId']! as String,
        nameAr: row['nameAr']! as String,
        basisQuantity: (row['basisQuantity'] as num?)?.toDouble(),
        basisUnit: row['basisUnit'] as String?,
        lines: _mapList(row['lines'])
            .map(
              (line) => RecipeLine(
                ingredientId: line['ingredientId']! as String,
                quantity: (line['quantity']! as num).toDouble(),
                unit: line['unit']! as String,
              ),
            )
            .toList(),
      );

  Map<String, Object?> _sizeOptionToRow(MenuItemSizeOption value) => {
        'id': value.id,
        'masterSizeId': value.masterSizeId,
        'labelAr': value.labelAr,
        'price': value.price,
      };

  MenuItemSizeOption _sizeOptionFromRow(Map<String, Object?> row) =>
      MenuItemSizeOption(
        id: row['id']! as String,
        masterSizeId: row['masterSizeId'] as String?,
        labelAr: row['labelAr']! as String,
        price: (row['price']! as num).toDouble(),
      );

  Map<String, Object?> _attachmentToRow(MenuItemAttachment value) => {
        'id': value.id,
        'masterAddonId': value.masterAddonId,
        'nameAr': value.nameAr,
        'price': value.price,
      };

  MenuItemAttachment _attachmentFromRow(Map<String, Object?> row) =>
      MenuItemAttachment(
        id: row['id']! as String,
        masterAddonId: row['masterAddonId'] as String?,
        nameAr: row['nameAr']! as String,
        price: (row['price']! as num).toDouble(),
      );

  Map<String, Object?> _weightedOptionToRow(WeightedPriceOption value) => {
        'id': value.id,
        'label': value.label,
        'weightKg': value.weightKg,
        'price': value.price,
      };

  WeightedPriceOption _weightedOptionFromRow(Map<String, Object?> row) =>
      WeightedPriceOption(
        id: row['id']! as String,
        label: row['label']! as String,
        weightKg: (row['weightKg']! as num).toDouble(),
        price: (row['price']! as num).toDouble(),
      );

  List<Map<String, Object?>> _mapList(Object? value) {
    return (value as List<Object?>? ?? const [])
        .map((entry) => Map<String, Object?>.from(entry! as Map))
        .toList();
  }

  DateTime? _date(Object? value) =>
      value is String ? DateTime.parse(value) : null;
}
