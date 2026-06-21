import '../domain/kitchen_printer.dart';
import '../domain/printer_repository.dart';

class InMemoryPrinterRepository implements PrinterRepository {
  InMemoryPrinterRepository({List<KitchenPrinter> printers = const []})
      : _printers = [...printers];

  final List<KitchenPrinter> _printers;

  @override
  Future<List<KitchenPrinter>> listKitchenPrinters({
    bool activeOnly = false,
  }) async {
    final printers = _printers
        .where((printer) => !activeOnly || printer.active)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return printers;
  }

  @override
  Future<KitchenPrinter> saveKitchenPrinter(KitchenPrinter printer) async {
    final now = DateTime.now();
    final next = printer.copyWith(
      copies: printer.copies.clamp(1, 5),
      createdAt: printer.createdAt ?? now,
      updatedAt: now,
    );
    final index = _printers.indexWhere((value) => value.id == printer.id);
    if (index < 0) {
      _printers.add(next);
    } else {
      _printers[index] = next;
    }
    return next;
  }

  @override
  Future<void> deleteKitchenPrinter(String id) async {
    _printers.removeWhere((printer) => printer.id == id);
  }

  @override
  Future<List<SystemPrinter>> listSystemPrinters() async => const [];
}
