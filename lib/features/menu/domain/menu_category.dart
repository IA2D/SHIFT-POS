class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.nameAr,
    this.parentId,
    this.sortOrder = 0,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String nameAr;
  final String? parentId;
  final int sortOrder;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MenuCategory copyWith({
    String? id,
    String? nameAr,
    String? parentId,
    int? sortOrder,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MenuCategory(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      parentId: parentId ?? this.parentId,
      sortOrder: sortOrder ?? this.sortOrder,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
