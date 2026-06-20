import 'package:flutter/material.dart';

import '../../../app/app_state_scope.dart';
import '../../../core/config/app_config.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/presentation/login_page.dart';
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
  AppUser? _user;
  int _selectedIndex = 0;
  bool _loadingUser = true;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadCurrentUser);
  }

  Future<void> _loadCurrentUser() async {
    final user = await AppStateScope.of(context).authRepository.currentUser();
    if (!mounted) return;
    setState(() {
      _user = user;
      _loadingUser = false;
    });
  }

  Future<String?> _login(String username, String password) async {
    final user = await AppStateScope.of(context).authRepository.login(
      username: username,
      password: password,
    );
    if (user == null) return 'اسم المستخدم أو كلمة المرور غير صحيحة.';
    if (!mounted) return null;
    setState(() {
      _user = user;
      _selectedIndex = 0;
    });
    return null;
  }

  Future<void> _logout() async {
    await AppStateScope.of(context).authRepository.logout();
    if (!mounted) return;
    setState(() {
      _user = null;
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingUser) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = _user;
    if (user == null) {
      return LoginPage(onLogin: _login);
    }

    final destinations = _destinationsFor(user);
    final selectedIndex = _selectedIndex.clamp(0, destinations.length - 1);

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
          Center(child: Text(user.username)),
          IconButton(
            tooltip: 'خروج',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: destinations
                .map(
                  (destination) => NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label),
                  ),
                )
                .toList(growable: false),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: destinations[selectedIndex].builder(context)),
        ],
      ),
    );
  }

  List<_ShellDestination> _destinationsFor(AppUser user) {
    return [
      if (user.can(Permission.accessPos))
        _ShellDestination(
          label: 'نقطة البيع',
          icon: Icons.point_of_sale_outlined,
          selectedIcon: Icons.point_of_sale,
          builder: (_) => PosPage(config: widget.config),
        ),
      if (user.can(Permission.accessManager))
        _ShellDestination(
          label: 'المدير',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          builder: (_) => ManagerPage(config: widget.config),
        ),
      if (user.can(Permission.manageSettings))
        _ShellDestination(
          label: 'الإعدادات',
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          builder: (_) => SettingsPage(config: widget.config),
        ),
    ];
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;
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
