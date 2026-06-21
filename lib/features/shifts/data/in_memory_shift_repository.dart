import '../domain/shift.dart';
import '../domain/shift_repository.dart';

class InMemoryShiftRepository implements ShiftRepository {
  InMemoryShiftRepository({required List<Shift> shifts})
      : _shifts = [...shifts];

  factory InMemoryShiftRepository.seeded() {
    final now = DateTime.now();
    return InMemoryShiftRepository(
      shifts: [
        Shift(
          id: 'shift-admin-open',
          cashierId: 'admin',
          cashierName: 'admin',
          status: ShiftStatus.open,
          openingCash: 500,
          openedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
  }

  final List<Shift> _shifts;

  @override
  Future<List<Shift>> listShifts() async {
    final shifts = [..._shifts];
    shifts.sort((a, b) => b.openedAt.compareTo(a.openedAt));
    return shifts;
  }

  @override
  Future<Shift?> getOpenShiftForCashier(String cashierId) async {
    for (final shift in _shifts) {
      if (shift.cashierId == cashierId && shift.status == ShiftStatus.open) {
        return shift;
      }
    }
    return null;
  }

  @override
  Future<Shift> saveShift(Shift shift) async {
    final index = _shifts.indexWhere((current) => current.id == shift.id);
    if (index == -1) {
      _shifts.add(shift);
    } else {
      _shifts[index] = shift;
    }
    return shift;
  }
}
