import 'dining_table.dart';

abstract interface class TableRepository {
  Future<List<DiningTable>> listTables();
}
