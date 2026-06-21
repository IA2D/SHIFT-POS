import 'package:flutter/material.dart';

import 'app_dependencies.dart';
import 'app_state_scope.dart';
import '../core/config/app_config.dart';
import '../core/database/backup_coordinator.dart';
import '../features/shell/presentation/app_shell.dart';
import '../shared/theme/app_theme.dart';

class ShiftPosApp extends StatefulWidget {
  const ShiftPosApp({
    required this.config,
    this.dependencies,
    super.key,
  });

  final AppConfig config;
  final AppDependencies? dependencies;

  @override
  State<ShiftPosApp> createState() => _ShiftPosAppState();
}

class _ShiftPosAppState extends State<ShiftPosApp> with WidgetsBindingObserver {
  late final AppDependencies _dependencies;

  @override
  void initState() {
    super.initState();
    _dependencies = widget.dependencies ?? AppDependencies();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.detached) return;
    final gateway = _dependencies.databaseGateway;
    if (gateway == null) return;
    BackupCoordinator(
      gateway: gateway,
      settingsRepository: _dependencies.settingsRepository,
      settingsNotifier: _dependencies.settingsNotifier,
    ).runOnCloseIfEnabled();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _dependencies.settingsNotifier,
      builder: (context, settings, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SHIFT POS',
        theme: AppTheme.light(brandColor: _parseColor(settings.primaryColor)),
        home: AppStateScope(
          dependencies: _dependencies,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: AppShell(config: widget.config),
          ),
        ),
      ),
    );
  }

  Color _parseColor(String value) {
    final normalized = value.replaceFirst('#', '');
    final parsed = int.tryParse(normalized, radix: 16);
    return parsed == null || normalized.length != 6
        ? AppTheme.primary
        : Color(0xFF000000 | parsed);
  }
}
