import 'dart:convert';
import 'dart:io';

import '../../../core/database/database_gateway.dart';
import '../../../core/database/database_tables.dart';
import '../domain/kitchen_printer.dart';
import '../domain/printer_repository.dart';

class SqlitePrinterRepository implements PrinterRepository {
  SqlitePrinterRepository(this._database);

  final DatabaseGateway _database;

  @override
  Future<List<KitchenPrinter>> listKitchenPrinters({
    bool activeOnly = false,
  }) async {
    final printers = (await _database.query(DatabaseTables.kitchenPrinters))
        .map(_fromRow)
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
    await _database.save(DatabaseTables.kitchenPrinters, next.id, {
      'name': next.name,
      'deviceName': next.deviceName,
      'description': next.description,
      'copies': next.copies,
      'active': next.active,
      'visibility': {
        'showOrderType': next.visibility.showOrderType,
        'showTable': next.visibility.showTable,
        'showCashier': next.visibility.showCashier,
        'showCustomer': next.visibility.showCustomer,
        'showOrderNote': next.visibility.showOrderNote,
        'showItemNotes': next.visibility.showItemNotes,
      },
      'createdAt': next.createdAt?.toIso8601String(),
      'updatedAt': next.updatedAt?.toIso8601String(),
    });
    return next;
  }

  @override
  Future<void> deleteKitchenPrinter(String id) async {
    await _database.delete(DatabaseTables.kitchenPrinters, id);
  }

  @override
  Future<List<SystemPrinter>> listSystemPrinters() async {
    if (!Platform.isWindows) return const [];
    final result = await Process.run(
      'powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r'Get-Printer | Select-Object Name,DriverName,Default | ConvertTo-Json -Compress',
      ],
      runInShell: false,
    );
    if (result.exitCode != 0 || (result.stdout as String).trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(result.stdout as String);
      final values = decoded is List ? decoded : [decoded];
      return values
          .whereType<Map>()
          .map((value) => Map<String, Object?>.from(value))
          .map((value) => SystemPrinter(
                name: value['Name']! as String,
                displayName: value['Name']! as String,
                description: value['DriverName'] as String?,
                isDefault: value['Default'] as bool? ?? false,
              ))
          .toList();
    } on FormatException {
      return const [];
    }
  }

  KitchenPrinter _fromRow(Map<String, Object?> row) {
    final visibility = Map<String, Object?>.from(row['visibility']! as Map);
    return KitchenPrinter(
      id: row['id']! as String,
      name: row['name']! as String,
      deviceName: row['deviceName']! as String,
      description: row['description'] as String?,
      copies: row['copies'] as int? ?? 1,
      active: row['active'] as bool? ?? true,
      visibility: KitchenPrinterVisibility(
        showOrderType: visibility['showOrderType'] as bool? ?? true,
        showTable: visibility['showTable'] as bool? ?? true,
        showCashier: visibility['showCashier'] as bool? ?? true,
        showCustomer: visibility['showCustomer'] as bool? ?? true,
        showOrderNote: visibility['showOrderNote'] as bool? ?? true,
        showItemNotes: visibility['showItemNotes'] as bool? ?? true,
      ),
      createdAt: _date(row['createdAt']),
      updatedAt: _date(row['updatedAt']),
    );
  }

  DateTime? _date(Object? value) =>
      value is String ? DateTime.parse(value) : null;
}
