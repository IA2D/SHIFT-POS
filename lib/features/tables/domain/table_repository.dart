import 'dining_table.dart';
import 'floor_plan.dart';

abstract interface class TableRepository {
  Future<List<DiningTable>> listTables();

  Future<DiningTable> saveTable(DiningTable table);

  Future<void> deleteTable(String id);

  Future<List<FloorPlanArea>> listFloors({bool includeInactive = false});

  Future<FloorPlanArea> saveFloor(FloorPlanArea floor);

  Future<void> deleteFloor(String id);

  Future<void> saveTables(List<DiningTable> tables);
}
