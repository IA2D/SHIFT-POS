class FloorPlanArea {
  const FloorPlanArea({
    required this.id,
    required this.nameAr,
    this.width = 1200,
    this.height = 800,
    this.backgroundColor,
    this.walls = const [],
    this.sortOrder = 0,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String nameAr;
  final double width;
  final double height;
  final String? backgroundColor;
  final List<FloorWall> walls;
  final int sortOrder;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FloorPlanArea copyWith({
    String? nameAr,
    double? width,
    double? height,
    String? backgroundColor,
    List<FloorWall>? walls,
    int? sortOrder,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FloorPlanArea(
      id: id,
      nameAr: nameAr ?? this.nameAr,
      width: width ?? this.width,
      height: height ?? this.height,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      walls: walls ?? this.walls,
      sortOrder: sortOrder ?? this.sortOrder,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class FloorWall {
  const FloorWall({
    required this.id,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    this.thickness = 6,
    this.color = '#555555',
  });

  final String id;
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double thickness;
  final String color;
}
