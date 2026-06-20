import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/widgets/page_header.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    required this.config,
    super.key,
  });

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
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
