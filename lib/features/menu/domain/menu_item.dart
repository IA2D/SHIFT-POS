class MenuItem {
  const MenuItem({
    required this.id,
    required this.categoryId,
    required this.nameAr,
    required this.price,
    this.active = true,
    this.kitchenPrinterIds = const [],
  });

  final String id;
  final String categoryId;
  final String nameAr;
  final double price;
  final bool active;
  final List<String> kitchenPrinterIds;
}
