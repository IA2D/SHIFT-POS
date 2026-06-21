import 'package:flutter/material.dart';

import '../../../app/app_state_scope.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/widgets/page_header.dart';
import '../../audit/domain/audit_event.dart';
import '../domain/pos_settings.dart';
import 'manager_settings_panel.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.config, super.key});

  final AppConfig config;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<PosSettings> _settings;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _settings = AppStateScope.of(context).settingsRepository.getPosSettings();
  }

  void _reload() {
    _settings = AppStateScope.of(context).settingsRepository.getPosSettings();
    setState(() {});
  }

  Future<void> _log(String action, String details) async {
    final dependencies = AppStateScope.of(context);
    final user = await dependencies.authRepository.currentUser();
    final now = DateTime.now();
    await dependencies.auditRepository.record(
      AuditEvent(
        id: 'audit-${now.microsecondsSinceEpoch}',
        action: action,
        actorUsername: user?.username ?? 'local',
        detailAr: details,
        targetType: 'settings',
        targetId: 'app',
        createdAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: FutureBuilder<PosSettings>(
        future: _settings,
        builder: (context, snapshot) {
          final settings = snapshot.data;
          if (settings == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            children: [
              const PageHeader(
                title: 'الإعدادات',
                subtitle: 'إعدادات نقطة البيع والطباعة والنسخ الاحتياطي.',
              ),
              const SizedBox(height: 14),
              ManagerSettingsPanel(
                key: ValueKey(settings),
                settings: settings,
                onChanged: _reload,
                onLog: _log,
              ),
              const SizedBox(height: 14),
              _RuntimeConfiguration(config: widget.config),
            ],
          );
        },
      ),
    );
  }
}

class _RuntimeConfiguration extends StatelessWidget {
  const _RuntimeConfiguration({required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Runtime configuration',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            _SettingRow(label: 'Environment', value: config.environment),
            _SettingRow(label: 'API endpoint', value: config.api.baseUrl),
            _SettingRow(label: 'Database', value: config.database.driver),
            _SettingRow(label: 'Database name', value: config.database.name),
            _SettingRow(
              label: 'Default master port',
              value: '${config.network.defaultMasterPort}',
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          SelectableText(value, textDirection: TextDirection.ltr),
        ],
      ),
    );
  }
}
