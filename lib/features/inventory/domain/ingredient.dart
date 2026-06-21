class Ingredient {
  const Ingredient({
    required this.id,
    required this.nameAr,
    required this.unit,
    this.lowStockThreshold,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String nameAr;
  final String unit;
  final double? lowStockThreshold;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Ingredient copyWith({
    String? id,
    String? nameAr,
    String? unit,
    double? lowStockThreshold,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Ingredient(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      unit: unit ?? this.unit,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class IngredientStock {
  const IngredientStock({
    required this.ingredientId,
    required this.nameAr,
    required this.unit,
    required this.quantity,
    this.lowStockThreshold,
  });

  final String ingredientId;
  final String nameAr;
  final String unit;
  final double quantity;
  final double? lowStockThreshold;

  bool get isLow {
    final threshold = lowStockThreshold;
    return threshold != null && quantity <= threshold;
  }
}
