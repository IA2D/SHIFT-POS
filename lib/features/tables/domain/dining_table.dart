class DiningTable {
  const DiningTable({
    required this.id,
    required this.nameAr,
    required this.sectionAr,
    this.sortOrder = 0,
  });

  final String id;
  final String nameAr;
  final String sectionAr;
  final int sortOrder;
}
