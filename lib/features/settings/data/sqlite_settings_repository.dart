import '../../../core/database/database_gateway.dart';
import '../../../core/database/database_tables.dart';
import '../domain/pos_settings.dart';
import '../domain/settings_repository.dart';
import 'in_memory_settings_repository.dart';

class SqliteSettingsRepository implements SettingsRepository {
  SqliteSettingsRepository(this._database);

  static const _posSettingsId = 'pos';
  final DatabaseGateway _database;

  Future<void> initialize() async {
    if ((await _database.query(DatabaseTables.settings)).isNotEmpty) return;
    final settings = await InMemorySettingsRepository().getPosSettings();
    await savePosSettings(settings);
  }

  @override
  Future<PosSettings> getPosSettings() async {
    final rows = await _database.query(
      DatabaseTables.settings,
      filters: {'id': _posSettingsId},
    );
    if (rows.isEmpty) throw StateError('POS settings are not initialized');
    final row = rows.single;
    final sectionOrder =
        (row['receiptSectionOrder'] as List<Object?>? ?? const [])
            .whereType<String>()
            .map((name) => ReceiptSection.values.byName(name))
            .toList();
    for (final section in ReceiptSection.values) {
      if (!sectionOrder.contains(section)) sectionOrder.add(section);
    }
    final hiddenNames =
        (row['receiptHiddenSections'] as List<Object?>? ?? const [])
            .whereType<String>()
            .toSet();
    return PosSettings(
      restaurantNameAr: row['restaurantNameAr']! as String,
      currencySymbol: row['currencySymbol']! as String,
      taxRate: (row['taxRate']! as num).toDouble(),
      serviceRate: (row['serviceRate']! as num).toDouble(),
      deliveryFee: (row['deliveryFee']! as num).toDouble(),
      phoneNumber: row['phoneNumber'] as String?,
      receiptFooterAr: row['receiptFooterAr'] as String?,
      primaryColor: row['primaryColor'] as String? ?? '#008C95',
      pinEnabled: row['pinEnabled'] as bool? ?? false,
      autoLockMinutes: row['autoLockMinutes'] as int? ?? 5,
      maxCashierDiscountPct: (row['maxCashierDiscountPct'] as num?)?.toDouble(),
      keyboardShortcuts: Map<String, String>.from(
        row['keyboardShortcuts'] as Map? ?? const {},
      ),
      networkMode: NetworkMode.values.byName(
        row['networkMode'] as String? ?? NetworkMode.standalone.name,
      ),
      masterServerPort: row['masterServerPort'] as int? ?? 47831,
      receiptPrintRoute: ReceiptPrintRoute.values.byName(
        row['receiptPrintRoute'] as String? ?? ReceiptPrintRoute.side.name,
      ),
      receiptSectionOrder: sectionOrder,
      receiptHiddenSections: ReceiptSection.values
          .where((section) => hiddenNames.contains(section.name))
          .toSet(),
      receiptShowItemNotes: row['receiptShowItemNotes'] as bool? ?? true,
      receiptCompactMode: row['receiptCompactMode'] as bool? ?? false,
      receiptLogoEnabled: row['receiptLogoEnabled'] as bool? ?? false,
      receiptLogoDataUrl: row['receiptLogoDataUrl'] as String?,
      receiptLogoMode: ReceiptLogoMode.values.byName(
        row['receiptLogoMode'] as String? ?? ReceiptLogoMode.image.name,
      ),
      receiptLogoThreshold: row['receiptLogoThreshold'] as int? ?? 176,
      receiptLogoWidth: row['receiptLogoWidth'] as int? ?? 96,
      receiptLogoInvert: row['receiptLogoInvert'] as bool? ?? false,
      receiptLogoAlign: ReceiptLogoAlign.values.byName(
        row['receiptLogoAlign'] as String? ?? ReceiptLogoAlign.center.name,
      ),
      receiptLogoMaxWidthPercent:
          row['receiptLogoMaxWidthPercent'] as int? ?? 100,
      defaultReceiptPrinter: row['defaultReceiptPrinter'] as String?,
      defaultReportPrinter: row['defaultReportPrinter'] as String?,
      backupDirectory: row['backupDirectory'] as String?,
      backupDirectories:
          (row['backupDirectories'] as List<Object?>? ?? const [])
              .whereType<String>()
              .toList(),
      autoBackupEnabled: row['autoBackupEnabled'] as bool? ?? false,
      autoBackupIntervalDays: row['autoBackupIntervalDays'] as int? ?? 1,
      autoBackupOnClose: row['autoBackupOnClose'] as bool? ?? false,
      backupRetentionDays: row['backupRetentionDays'] as int? ?? 7,
      lastAutoBackupAt: _date(row['lastAutoBackupAt']),
    );
  }

  @override
  Future<PosSettings> savePosSettings(PosSettings settings) async {
    await _database.save(DatabaseTables.settings, _posSettingsId, {
      'restaurantNameAr': settings.restaurantNameAr,
      'currencySymbol': settings.currencySymbol,
      'taxRate': settings.taxRate,
      'serviceRate': settings.serviceRate,
      'deliveryFee': settings.deliveryFee,
      'phoneNumber': settings.phoneNumber,
      'receiptFooterAr': settings.receiptFooterAr,
      'primaryColor': settings.primaryColor,
      'pinEnabled': settings.pinEnabled,
      'autoLockMinutes': settings.autoLockMinutes,
      'maxCashierDiscountPct': settings.maxCashierDiscountPct,
      'keyboardShortcuts': settings.keyboardShortcuts,
      'networkMode': settings.networkMode.name,
      'masterServerPort': settings.masterServerPort,
      'receiptPrintRoute': settings.receiptPrintRoute.name,
      'receiptSectionOrder':
          settings.receiptSectionOrder.map((section) => section.name).toList(),
      'receiptHiddenSections': settings.receiptHiddenSections
          .map((section) => section.name)
          .toList(),
      'receiptShowItemNotes': settings.receiptShowItemNotes,
      'receiptCompactMode': settings.receiptCompactMode,
      'receiptLogoEnabled': settings.receiptLogoEnabled,
      'receiptLogoDataUrl': settings.receiptLogoDataUrl,
      'receiptLogoMode': settings.receiptLogoMode.name,
      'receiptLogoThreshold': settings.receiptLogoThreshold,
      'receiptLogoWidth': settings.receiptLogoWidth,
      'receiptLogoInvert': settings.receiptLogoInvert,
      'receiptLogoAlign': settings.receiptLogoAlign.name,
      'receiptLogoMaxWidthPercent': settings.receiptLogoMaxWidthPercent,
      'defaultReceiptPrinter': settings.defaultReceiptPrinter,
      'defaultReportPrinter': settings.defaultReportPrinter,
      'backupDirectory': settings.backupDirectory,
      'backupDirectories': settings.backupDirectories,
      'autoBackupEnabled': settings.autoBackupEnabled,
      'autoBackupIntervalDays': settings.autoBackupIntervalDays,
      'autoBackupOnClose': settings.autoBackupOnClose,
      'backupRetentionDays': settings.backupRetentionDays,
      'lastAutoBackupAt': settings.lastAutoBackupAt?.toIso8601String(),
    });
    return settings;
  }

  DateTime? _date(Object? value) =>
      value is String ? DateTime.parse(value) : null;
}
