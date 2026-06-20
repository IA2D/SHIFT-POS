import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/widgets/page_header.dart';

class ManagerPage extends StatelessWidget {
  const ManagerPage({
    required this.config,
    super.key,
  });

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'لوحة المدير',
            subtitle: 'إدارة الأصناف والمخزون والمستخدمين ستبنى كوحدات منفصلة.',
          ),
          SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ManagerCard(title: 'الأصناف', icon: Icons.restaurant_menu),
              _ManagerCard(title: 'المخزون', icon: Icons.inventory_2),
              _ManagerCard(title: 'الموردين', icon: Icons.local_shipping),
              _ManagerCard(title: 'التقارير', icon: Icons.bar_chart),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManagerCard extends StatelessWidget {
  const _ManagerCard({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 120,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
