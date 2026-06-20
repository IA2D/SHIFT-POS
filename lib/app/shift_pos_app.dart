import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../features/shell/presentation/app_shell.dart';
import '../shared/theme/app_theme.dart';

class ShiftPosApp extends StatelessWidget {
  const ShiftPosApp({
    required this.config,
    super.key,
  });

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SHIFT POS',
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: AppShell(config: config),
      ),
    );
  }
}
