import '../../../core/database/database_gateway.dart';
import '../../../core/database/database_tables.dart';
import '../domain/dining_table.dart';
import '../domain/floor_plan.dart';
import '../domain/table_repository.dart';
import 'in_memory_table_repository.dart';

class SqliteTableRepository implements TableRepository {
  SqliteTableRepository(this._database);

  final DatabaseGateway _database;

  Future<void> initialize() async {
    final seed = InMemoryTableRepository.seeded();
    if ((await _database.query(DatabaseTables.floors)).isEmpty) {
      for (final floor in await seed.listFloors()) {
        await saveFloor(floor);
      }
    }
    if ((await _database.query(DatabaseTables.diningTables)).isEmpty) {
      for (final table in await seed.listTables()) {
        await saveTable(table);
      }
    }
  }

  @override
  Future<List<DiningTable>> listTables() async {
    final tables = (await _database.query(DatabaseTables.diningTables))
        .map(
          (row) => DiningTable(
            id: row['id']! as String,
            nameAr: row['nameAr']! as String,
            sectionAr: row['sectionAr']! as String,
            sortOrder: row['sortOrder'] as int? ?? 0,
            active: row['active'] as bool? ?? true,
            floorId: row['floorId'] as String?,
            x: (row['x'] as num?)?.toDouble(),
            y: (row['y'] as num?)?.toDouble(),
            width: (row['width'] as num?)?.toDouble() ?? 90,
            height: (row['height'] as num?)?.toDouble() ?? 90,
            shape: row['shape'] == TableShape.circle.name
                ? TableShape.circle
                : TableShape.rectangle,
            seats: row['seats'] as int? ?? 4,
            chairPositions: _mapList(row['chairPositions'])
                .map(
                  (chair) => TableChairPosition(
                    id: chair['id']! as String,
                    x: (chair['x']! as num).toDouble(),
                    y: (chair['y']! as num).toDouble(),
                  ),
                )
                .toList(),
            rotation: (row['rotation'] as num?)?.toDouble() ?? 0,
            createdAt: _date(row['createdAt']),
            updatedAt: _date(row['updatedAt']),
          ),
        )
        .toList();
    tables.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return tables;
  }

  @override
  Future<DiningTable> saveTable(DiningTable table) async {
    await _database.save(DatabaseTables.diningTables, table.id, {
      'nameAr': table.nameAr,
      'sectionAr': table.sectionAr,
      'sortOrder': table.sortOrder,
      'active': table.active,
      'floorId': table.floorId,
      'x': table.x,
      'y': table.y,
      'width': table.width,
      'height': table.height,
      'shape': table.shape.name,
      'seats': table.seats,
      'chairPositions': table.chairPositions
          .map((chair) => {'id': chair.id, 'x': chair.x, 'y': chair.y})
          .toList(),
      'rotation': table.rotation,
      'createdAt': table.createdAt?.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
    return table;
  }

  @override
  Future<void> deleteTable(String id) async {
    await _database.delete(DatabaseTables.diningTables, id);
  }

  @override
  Future<List<FloorPlanArea>> listFloors({bool includeInactive = false}) async {
    final floors = (await _database.query(DatabaseTables.floors))
        .map(_floorFromRow)
        .where((floor) => includeInactive || floor.active)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return floors;
  }

  @override
  Future<FloorPlanArea> saveFloor(FloorPlanArea floor) async {
    final now = DateTime.now();
    final next = floor.copyWith(
      createdAt: floor.createdAt ?? now,
      updatedAt: now,
    );
    await _database.save(DatabaseTables.floors, floor.id, {
      'nameAr': next.nameAr,
      'width': next.width,
      'height': next.height,
      'backgroundColor': next.backgroundColor,
      'walls': next.walls
          .map(
            (wall) => {
              'id': wall.id,
              'x1': wall.x1,
              'y1': wall.y1,
              'x2': wall.x2,
              'y2': wall.y2,
              'thickness': wall.thickness,
              'color': wall.color,
            },
          )
          .toList(),
      'sortOrder': next.sortOrder,
      'active': next.active,
      'createdAt': next.createdAt?.toIso8601String(),
      'updatedAt': next.updatedAt?.toIso8601String(),
    });
    return next;
  }

  @override
  Future<void> deleteFloor(String id) async {
    final tables = await listTables();
    for (final table in tables.where((value) => value.floorId == id)) {
      await deleteTable(table.id);
    }
    await _database.delete(DatabaseTables.floors, id);
  }

  @override
  Future<void> saveTables(List<DiningTable> tables) async {
    for (final table in tables) {
      await saveTable(table);
    }
  }

  FloorPlanArea _floorFromRow(Map<String, Object?> row) => FloorPlanArea(
        id: row['id']! as String,
        nameAr: row['nameAr']! as String,
        width: (row['width'] as num?)?.toDouble() ?? 1200,
        height: (row['height'] as num?)?.toDouble() ?? 800,
        backgroundColor: row['backgroundColor'] as String?,
        walls: _mapList(row['walls'])
            .map(
              (wall) => FloorWall(
                id: wall['id']! as String,
                x1: (wall['x1']! as num).toDouble(),
                y1: (wall['y1']! as num).toDouble(),
                x2: (wall['x2']! as num).toDouble(),
                y2: (wall['y2']! as num).toDouble(),
                thickness: (wall['thickness'] as num?)?.toDouble() ?? 6,
                color: wall['color'] as String? ?? '#555555',
              ),
            )
            .toList(),
        sortOrder: row['sortOrder'] as int? ?? 0,
        active: row['active'] as bool? ?? true,
        createdAt: _date(row['createdAt']),
        updatedAt: _date(row['updatedAt']),
      );

  List<Map<String, Object?>> _mapList(Object? value) =>
      (value as List<Object?>? ?? const [])
          .map((entry) => Map<String, Object?>.from(entry! as Map))
          .toList();

  DateTime? _date(Object? value) =>
      value is String ? DateTime.parse(value) : null;
}
