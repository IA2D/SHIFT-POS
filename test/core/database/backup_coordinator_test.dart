import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_pos/core/database/backup_coordinator.dart';
import 'package:shift_pos/core/database/database_gateway.dart';
import 'package:shift_pos/features/settings/data/in_memory_settings_repository.dart';
import 'package:shift_pos/features/settings/domain/pos_settings.dart';

void main() {
  test('copies to configured directories, prunes old files, and records run',
      () async {
    final root = await Directory.systemTemp.createTemp('shift_backup_test_');
    addTearDown(() => root.delete(recursive: true));
    final first = Directory('${root.path}\\first')..createSync();
    final second = Directory('${root.path}\\second')..createSync();
    final expired = File('${first.path}\\shift_pos_expired.sqlite')
      ..writeAsStringSync('old');
    expired
        .setLastModifiedSync(DateTime.now().subtract(const Duration(days: 5)));

    final settings = PosSettings(
      restaurantNameAr: 'SHIFT',
      currencySymbol: 'EGP',
      taxRate: 0,
      serviceRate: 0,
      deliveryFee: 0,
      autoBackupEnabled: true,
      autoBackupIntervalDays: 1,
      backupDirectory: first.path,
      backupDirectories: [second.path],
      backupRetentionDays: 2,
    );
    final repository = InMemorySettingsRepository(settings: settings);
    final notifier = ValueNotifier(settings);
    final coordinator = BackupCoordinator(
      gateway: _FakeGateway(),
      settingsRepository: repository,
      settingsNotifier: notifier,
    );

    final paths = await coordinator.runIfDue();

    expect(paths, hasLength(2));
    expect(paths.every((value) => File(value).existsSync()), isTrue);
    expect(expired.existsSync(), isFalse);
    expect((await repository.getPosSettings()).lastAutoBackupAt, isNotNull);
    expect(await coordinator.runIfDue(), isEmpty);
  });
}

class _FakeGateway implements DatabaseGateway {
  @override
  Future<String> createBackup({String? directoryPath}) async {
    final directory = Directory(directoryPath!)..createSync(recursive: true);
    final file = File(
      '${directory.path}\\shift_pos_${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    await file.writeAsString('backup');
    return file.path;
  }

  @override
  Future<void> delete(String table, String id) async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    Map<String, Object?> filters = const {},
  }) async =>
      const [];

  @override
  Future<void> restoreBackup(String filePath) async {}

  @override
  Future<void> save(
    String table,
    String id,
    Map<String, Object?> data,
  ) async {}
}
