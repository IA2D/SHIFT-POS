import 'package:flutter/material.dart';

import '../../../app/app_state_scope.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/widgets/page_header.dart';
import '../domain/pos_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    required this.config,
    super.key,
  });

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final settingsFuture = AppStateScope.of(context).settingsRepository.getPosSettings();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          const PageHeader(
            title: 'الإعدادات',
            subtitle: 'القيم الأساسية تقرأ من ملف config قابل للتعديل.',
          ),
          const SizedBox(height: 24),
          _SettingRow(label: 'البيئة', value: config.environment),
          _SettingRow(
            label: 'ربط API',
            value: config.api.enabled ? 'مفعل' : 'معطل',
          ),
          _SettingRow(label: 'API endpoint', value: config.api.baseUrl),
          _SettingRow(
            label: 'ربط قاعدة البيانات',
            value: config.database.enabled ? 'مفعل' : 'معطل',
          ),
          _SettingRow(label: 'نوع قاعدة البيانات', value: config.database.driver),
          _SettingRow(label: 'اسم قاعدة البيانات', value: config.database.name),
          _SettingRow(
            label: 'منفذ الماستر الافتراضي',
            value: config.network.defaultMasterPort.toString(),
          ),
          const SizedBox(height: 12),
          FutureBuilder<PosSettings>(
            future: settingsFuture,
            builder: (context, snapshot) {
              final settings = snapshot.data;
              if (settings == null) {
                return const Center(child: CircularProgressIndicator());
              }

              return Column(
                children: [
                  _SettingRow(label: 'اسم المطعم', value: settings.restaurantNameAr),
                  _SettingRow(label: 'العملة', value: settings.currencySymbol),
                  _SettingRow(label: 'الضريبة', value: '${settings.taxRate.toStringAsFixed(2)}%'),
                  _SettingRow(label: 'الخدمة', value: '${settings.serviceRate.toStringAsFixed(2)}%'),
                  _SettingRow(label: 'رسوم الدليفري', value: settings.deliveryFee.toStringAsFixed(2)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              SelectableText(value, textDirection: TextDirection.ltr),
            ],
          ),
        ),
      ),
    );
  }
}
