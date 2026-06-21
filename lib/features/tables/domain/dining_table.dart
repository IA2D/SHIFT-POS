class DiningTable {
  const DiningTable({
    required this.id,
    required this.nameAr,
    this.sectionAr = 'الصالة',
    this.sortOrder = 0,
    this.active = true,
    this.floorId,
    this.x,
    this.y,
    this.width = 90,
    this.height = 90,
    this.shape = TableShape.rectangle,
    this.seats = 4,
    this.chairPositions = const [],
    this.rotation = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String nameAr;
  final String sectionAr;
  final int sortOrder;
  final bool active;
  final String? floorId;
  final double? x;
  final double? y;
  final double width;
  final double height;
  final TableShape shape;
  final int seats;
  final List<TableChairPosition> chairPositions;
  final double rotation;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DiningTable copyWith({
    String? nameAr,
    String? sectionAr,
    int? sortOrder,
    bool? active,
    String? floorId,
    double? x,
    double? y,
    double? width,
    double? height,
    TableShape? shape,
    int? seats,
    List<TableChairPosition>? chairPositions,
    double? rotation,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiningTable(
      id: id,
      nameAr: nameAr ?? this.nameAr,
      sectionAr: sectionAr ?? this.sectionAr,
      sortOrder: sortOrder ?? this.sortOrder,
      active: active ?? this.active,
      floorId: floorId ?? this.floorId,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      shape: shape ?? this.shape,
      seats: seats ?? this.seats,
      chairPositions: chairPositions ?? this.chairPositions,
      rotation: rotation ?? this.rotation,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum TableShape { rectangle, circle }

class TableChairPosition {
  const TableChairPosition({
    required this.id,
    required this.x,
    required this.y,
  });

  final String id;
  final double x;
  final double y;

  TableChairPosition copyWith({double? x, double? y}) {
    return TableChairPosition(id: id, x: x ?? this.x, y: y ?? this.y);
  }
}
