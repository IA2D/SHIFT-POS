import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../manager/presentation/manager_page.dart';
import '../../pos/presentation/pos_page.dart';
import '../../settings/presentation/settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.config,
    super.key,
  });

  final AppConfig config;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      PosPage(config: widget.config),
      ManagerPage(config: widget.config),
      SettingsPage(config: widget.config),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('SHIFT POS'),
        actions: [
          _StatusChip(
            label: widget.config.database.enabled
                ? 'قاعدة البيانات مفعلة'
                : 'قاعدة البيانات معطلة',
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.point_of_sale_outlined),
                selectedIcon: Icon(Icons.point_of_sale),
                label: Text('نقطة البيع'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('المدير'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('الإعدادات'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: pages[_selectedIndex]),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
      ),
    );
  }
}
