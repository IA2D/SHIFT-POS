import 'kitchen_printer.dart';

abstract interface class PrinterRepository {
  Future<List<KitchenPrinter>> listKitchenPrinters({bool activeOnly = false});

  Future<KitchenPrinter> saveKitchenPrinter(KitchenPrinter printer);

  Future<void> deleteKitchenPrinter(String id);

  Future<List<SystemPrinter>> listSystemPrinters();
}
