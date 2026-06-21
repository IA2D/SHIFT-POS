import '../domain/dining_table.dart';
import '../domain/floor_plan.dart';
import '../domain/table_repository.dart';

class InMemoryTableRepository implements TableRepository {
  InMemoryTableRepository({
    required List<DiningTable> tables,
    List<FloorPlanArea> floors = const [],
  })  : _tables = [...tables],
        _floors = [...floors];

  factory InMemoryTableRepository.seeded() {
    return InMemoryTableRepository(
      floors: const [
        FloorPlanArea(id: 'floor-salon', nameAr: 'الصالة', sortOrder: 1),
        FloorPlanArea(id: 'floor-outdoor', nameAr: 'خارجي', sortOrder: 2),
      ],
      tables: const [
        DiningTable(
          id: 't1',
          nameAr: 'ترابيزة 1',
          sectionAr: 'الصالة',
          floorId: 'floor-salon',
          x: 140,
          y: 140,
          sortOrder: 1,
        ),
        DiningTable(
          id: 't2',
          nameAr: 'ترابيزة 2',
          sectionAr: 'الصالة',
          floorId: 'floor-salon',
          x: 340,
          y: 140,
          shape: TableShape.circle,
          sortOrder: 2,
        ),
        DiningTable(
          id: 't3',
          nameAr: 'ترابيزة 3',
          sectionAr: 'الصالة',
          floorId: 'floor-salon',
          x: 540,
          y: 140,
          sortOrder: 3,
        ),
        DiningTable(
          id: 'garden-1',
          nameAr: 'خارجي 1',
          sectionAr: 'خارجي',
          floorId: 'floor-outdoor',
          x: 160,
          y: 160,
          sortOrder: 10,
        ),
      ],
    );
  }

  final List<DiningTable> _tables;
  final List<FloorPlanArea> _floors;

  @override
  Future<List<DiningTable>> listTables() async {
    final tables = [..._tables];
    tables.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return tables;
  }

  @override
  Future<DiningTable> saveTable(DiningTable table) async {
    final index = _tables.indexWhere((value) => value.id == table.id);
    if (index < 0) {
      _tables.add(table);
    } else {
      _tables[index] = table;
    }
    return table;
  }

  @override
  Future<void> deleteTable(String id) async {
    _tables.removeWhere((value) => value.id == id);
  }

  @override
  Future<List<FloorPlanArea>> listFloors({bool includeInactive = false}) async {
    final floors = _floors
        .where((floor) => includeInactive || floor.active)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return floors;
  }

  @override
  Future<FloorPlanArea> saveFloor(FloorPlanArea floor) async {
    final index = _floors.indexWhere((value) => value.id == floor.id);
    if (index < 0) {
      _floors.add(floor);
    } else {
      _floors[index] = floor;
    }
    return floor;
  }

  @override
  Future<void> deleteFloor(String id) async {
    _floors.removeWhere((value) => value.id == id);
    _tables.removeWhere((value) => value.floorId == id);
  }

  @override
  Future<void> saveTables(List<DiningTable> tables) async {
    for (final table in tables) {
      await saveTable(table);
    }
  }
}
