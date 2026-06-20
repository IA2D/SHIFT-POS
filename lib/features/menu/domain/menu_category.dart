class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.nameAr,
    this.parentId,
    this.sortOrder = 0,
  });

  final String id;
  final String nameAr;
  final String? parentId;
  final int sortOrder;
}
