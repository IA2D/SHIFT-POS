enum MenuItemType {
  product,
  rawMaterial,
  service,
}

enum ProductType {
  recipe,
  readyMade,
  manufactured,
  noInventory,
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.categoryId,
    required this.nameAr,
    required this.price,
    this.descriptionAr,
    this.itemType = MenuItemType.product,
    this.productType = ProductType.recipe,
    this.linkedIngredientId,
    this.sizeOptions = const [],
    this.attachments = const [],
    this.isWeighted = false,
    this.weightedPriceOptions = const [],
    this.allowCustomWeight = false,
    this.customWeightUnitPrice,
    this.kitchenPrinterIds = const [],
    this.imageUrl,
    this.active = true,
    this.recipeId = '',
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String categoryId;
  final String nameAr;
  final String? descriptionAr;
  final double price;
  final MenuItemType itemType;
  final ProductType productType;
  final String? linkedIngredientId;
  final List<MenuItemSizeOption> sizeOptions;
  final List<MenuItemAttachment> attachments;
  final bool isWeighted;
  final List<WeightedPriceOption> weightedPriceOptions;
  final bool allowCustomWeight;
  final double? customWeightUnitPrice;
  final List<String> kitchenPrinterIds;
  final String? imageUrl;
  final bool active;
  final String recipeId;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MenuItem copyWith({
    String? id,
    String? categoryId,
    String? nameAr,
    String? descriptionAr,
    double? price,
    MenuItemType? itemType,
    ProductType? productType,
    String? linkedIngredientId,
    List<MenuItemSizeOption>? sizeOptions,
    List<MenuItemAttachment>? attachments,
    bool? isWeighted,
    List<WeightedPriceOption>? weightedPriceOptions,
    bool? allowCustomWeight,
    double? customWeightUnitPrice,
    List<String>? kitchenPrinterIds,
    String? imageUrl,
    bool? active,
    String? recipeId,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MenuItem(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      nameAr: nameAr ?? this.nameAr,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      price: price ?? this.price,
      itemType: itemType ?? this.itemType,
      productType: productType ?? this.productType,
      linkedIngredientId: linkedIngredientId ?? this.linkedIngredientId,
      sizeOptions: sizeOptions ?? this.sizeOptions,
      attachments: attachments ?? this.attachments,
      isWeighted: isWeighted ?? this.isWeighted,
      weightedPriceOptions: weightedPriceOptions ?? this.weightedPriceOptions,
      allowCustomWeight: allowCustomWeight ?? this.allowCustomWeight,
      customWeightUnitPrice:
          customWeightUnitPrice ?? this.customWeightUnitPrice,
      kitchenPrinterIds: kitchenPrinterIds ?? this.kitchenPrinterIds,
      imageUrl: imageUrl ?? this.imageUrl,
      active: active ?? this.active,
      recipeId: recipeId ?? this.recipeId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MenuItemSizeOption {
  const MenuItemSizeOption({
    required this.id,
    required this.labelAr,
    required this.price,
    this.masterSizeId,
  });

  final String id;
  final String? masterSizeId;
  final String labelAr;
  final double price;
}

class MenuItemAttachment {
  const MenuItemAttachment({
    required this.id,
    required this.nameAr,
    required this.price,
    this.masterAddonId,
  });

  final String id;
  final String? masterAddonId;
  final String nameAr;
  final double price;
}

class WeightedPriceOption {
  const WeightedPriceOption({
    required this.id,
    required this.label,
    required this.weightKg,
    required this.price,
  });

  final String id;
  final String label;
  final double weightKg;
  final double price;
}

class ItemSize {
  const ItemSize({
    required this.id,
    required this.nameAr,
    this.sortOrder = 0,
    this.active = true,
  });

  final String id;
  final String nameAr;
  final int sortOrder;
  final bool active;
}

class ItemAddon {
  const ItemAddon({
    required this.id,
    required this.nameAr,
    required this.defaultPrice,
    this.sortOrder = 0,
    this.active = true,
  });

  final String id;
  final String nameAr;
  final double defaultPrice;
  final int sortOrder;
  final bool active;
}

class RecipeLine {
  const RecipeLine({
    required this.ingredientId,
    required this.quantity,
    required this.unit,
  });

  final String ingredientId;
  final double quantity;
  final String unit;
}

class Recipe {
  const Recipe({
    required this.id,
    required this.menuItemId,
    required this.nameAr,
    this.basisQuantity,
    this.basisUnit,
    this.lines = const [],
  });

  final String id;
  final String menuItemId;
  final String nameAr;
  final double? basisQuantity;
  final String? basisUnit;
  final List<RecipeLine> lines;
}
