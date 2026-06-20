import 'package:flutter/material.dart';

import 'app_dependencies.dart';
import 'app_state_scope.dart';
import '../core/config/app_config.dart';
import '../features/shell/presentation/app_shell.dart';
import '../shared/theme/app_theme.dart';

class ShiftPosApp extends StatelessWidget {
  const ShiftPosApp({
    required this.config,
    this.dependencies,
    super.key,
  });

  final AppConfig config;
  final AppDependencies? dependencies;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SHIFT POS',
      theme: AppTheme.light(),
      home: AppStateScope(
        dependencies: dependencies ?? AppDependencies(),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: AppShell(config: config),
        ),
      ),
    );
  }
}
