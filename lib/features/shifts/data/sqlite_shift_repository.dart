import '../../../core/database/database_gateway.dart';
import '../../../core/database/database_tables.dart';
import '../domain/shift.dart';
import '../domain/shift_repository.dart';
import 'in_memory_shift_repository.dart';

class SqliteShiftRepository implements ShiftRepository {
  SqliteShiftRepository(this._database);

  final DatabaseGateway _database;

  Future<void> initialize() async {
    if ((await _database.query(DatabaseTables.shifts)).isNotEmpty) return;
    final seed = InMemoryShiftRepository.seeded();
    for (final shift in await seed.listShifts()) {
      await saveShift(shift);
    }
  }

  @override
  Future<List<Shift>> listShifts() async {
    final rows = await _database.query(DatabaseTables.shifts);
    final shifts = rows.map(_shiftFromRow).toList();
    shifts.sort((a, b) => b.openedAt.compareTo(a.openedAt));
    return shifts;
  }

  @override
  Future<Shift?> getOpenShiftForCashier(String cashierId) async {
    final shifts = await listShifts();
    for (final shift in shifts) {
      if (shift.cashierId == cashierId && shift.status == ShiftStatus.open) {
        return shift;
      }
    }
    return null;
  }

  @override
  Future<Shift> saveShift(Shift shift) async {
    await _database.save(DatabaseTables.shifts, shift.id, {
      'cashierId': shift.cashierId,
      'cashierName': shift.cashierName,
      'cashierCode': shift.cashierCode,
      'status': shift.status.name,
      'archived': shift.archived,
      'openingCash': shift.openingCash,
      'openedAt': shift.openedAt.toIso8601String(),
      'closedAt': shift.closedAt?.toIso8601String(),
      'closedBy': shift.closedBy,
      'closingCash': shift.closingCash,
      'createdAt': shift.createdAt.toIso8601String(),
      'updatedAt': shift.updatedAt.toIso8601String(),
    });
    return shift;
  }

  Shift _shiftFromRow(Map<String, Object?> row) => Shift(
        id: row['id']! as String,
        cashierId: row['cashierId']! as String,
        cashierName: row['cashierName']! as String,
        cashierCode: row['cashierCode'] as String?,
        status: ShiftStatus.values.byName(row['status']! as String),
        archived: row['archived'] as bool? ?? false,
        openingCash: (row['openingCash'] as num?)?.toDouble(),
        openedAt: DateTime.parse(row['openedAt']! as String),
        closedAt: _date(row['closedAt']),
        closedBy: row['closedBy'] as String?,
        closingCash: (row['closingCash'] as num?)?.toDouble(),
        createdAt: DateTime.parse(row['createdAt']! as String),
        updatedAt: DateTime.parse(row['updatedAt']! as String),
      );

  DateTime? _date(Object? value) =>
      value is String ? DateTime.parse(value) : null;
}
