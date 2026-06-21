import 'package:flutter/material.dart';

import 'app/shift_pos_app.dart';
import 'app/app_dependencies.dart';
import 'core/config/config_loader.dart';
import 'core/database/backup_coordinator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = await ConfigLoader.load();
  final dependencies = await AppDependencies.create(config);
  final gateway = dependencies.databaseGateway;
  if (gateway != null) {
    try {
      await BackupCoordinator(
        gateway: gateway,
        settingsRepository: dependencies.settingsRepository,
        settingsNotifier: dependencies.settingsNotifier,
      ).runIfDue();
    } on Object {
      // Backup failures must not prevent the POS from opening.
    }
  }

  runApp(ShiftPosApp(config: config, dependencies: dependencies));
}
