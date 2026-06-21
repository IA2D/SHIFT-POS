import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../features/settings/domain/pos_settings.dart';
import '../../features/settings/domain/settings_repository.dart';
import 'database_gateway.dart';

class BackupCoordinator {
  BackupCoordinator({
    required this.gateway,
    required this.settingsRepository,
    required this.settingsNotifier,
  });

  final DatabaseGateway gateway;
  final SettingsRepository settingsRepository;
  final ValueNotifier<PosSettings> settingsNotifier;
  bool _running = false;

  Future<List<String>> runIfDue() async {
    final settings = await settingsRepository.getPosSettings();
    if (!settings.autoBackupEnabled) return const [];
    final last = settings.lastAutoBackupAt;
    final dueAfter = Duration(days: settings.autoBackupIntervalDays);
    if (last != null && DateTime.now().difference(last) < dueAfter) {
      return const [];
    }
    return runConfiguredBackup(settings);
  }

  Future<List<String>> runOnCloseIfEnabled() async {
    final settings = await settingsRepository.getPosSettings();
    if (!settings.autoBackupOnClose) return const [];
    return runConfiguredBackup(settings);
  }

  Future<List<String>> runConfiguredBackup(PosSettings settings) async {
    if (_running) return const [];
    _running = true;
    try {
      final configured = <String>{
        if ((settings.backupDirectory ?? '').trim().isNotEmpty)
          settings.backupDirectory!.trim(),
        ...settings.backupDirectories
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
      }.toList();
      final paths = <String>[];
      if (configured.isEmpty) {
        paths.add(await gateway.createBackup());
      } else {
        for (final directory in configured) {
          paths.add(await gateway.createBackup(directoryPath: directory));
        }
      }
      if (settings.backupRetentionDays > 0) {
        for (final path in paths) {
          await _prune(
            File(path).parent,
            Duration(days: settings.backupRetentionDays),
          );
        }
      }
      final updated = settings.copyWith(lastAutoBackupAt: DateTime.now());
      await settingsRepository.savePosSettings(updated);
      settingsNotifier.value = updated;
      return paths;
    } finally {
      _running = false;
    }
  }

  Future<void> _prune(Directory directory, Duration retention) async {
    if (!await directory.exists()) return;
    final cutoff = DateTime.now().subtract(retention);
    await for (final entity in directory.list()) {
      if (entity is! File ||
          !entity.path.toLowerCase().endsWith('.sqlite') ||
          !entity.uri.pathSegments.last.startsWith('shift_pos_')) {
        continue;
      }
      final modified = await entity.lastModified();
      if (modified.isBefore(cutoff)) await entity.delete();
    }
  }
}
