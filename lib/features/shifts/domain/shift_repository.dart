import 'shift.dart';

abstract interface class ShiftRepository {
  Future<List<Shift>> listShifts();

  Future<Shift?> getOpenShiftForCashier(String cashierId);

  Future<Shift> saveShift(Shift shift);
}
