import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_command_bus.dart';
import '../../../app/app_dependencies.dart';
import '../../../app/app_state_scope.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/theme/app_theme.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/presentation/login_page.dart';
import '../../manager/presentation/manager_page.dart';
import '../../pos/presentation/pos_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../../shifts/domain/shift.dart';

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
  bool _locked = false;
  Timer? _autoLockTimer;
  AppDependencies? _dependencies;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadCurrentUser);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dependencies = AppStateScope.of(context);
    if (identical(_dependencies, dependencies)) return;
    _dependencies?.settingsNotifier.removeListener(_resetAutoLock);
    _dependencies = dependencies;
    dependencies.settingsNotifier.addListener(_resetAutoLock);
    _resetAutoLock();
  }

  @override
  void dispose() {
    _autoLockTimer?.cancel();
    _dependencies?.settingsNotifier.removeListener(_resetAutoLock);
    super.dispose();
  }

  void _resetAutoLock() {
    _autoLockTimer?.cancel();
    final settings = _dependencies?.settingsNotifier.value;
    if (_user == null ||
        _locked ||
        _user!.role != UserRole.cashier ||
        _user!.pin == null ||
        settings == null ||
        !settings.pinEnabled ||
        settings.autoLockMinutes <= 0) {
      return;
    }
    _autoLockTimer = Timer(
      Duration(minutes: settings.autoLockMinutes),
      _lockForInactivity,
    );
  }

  Future<void> _lockForInactivity() async {
    if (!mounted) return;
    setState(() => _locked = true);
  }

  Future<bool> _unlockPin(String pin) async {
    final user = _user;
    if (user == null) return false;
    final valid =
        await _dependencies?.authRepository.verifyPin(user.id, pin) ?? false;
    if (!valid || !mounted) return valid;
    setState(() => _locked = false);
    _resetAutoLock();
    return true;
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    _resetAutoLock();
    if (event is! KeyDownEvent || _user == null || _locked) {
      return KeyEventResult.ignored;
    }
    final shortcut = _shortcutFor(event.logicalKey);
    final shortcuts = _dependencies?.settingsNotifier.value.keyboardShortcuts;
    if (shortcuts == null) return KeyEventResult.ignored;

    final action = shortcuts.entries
        .where((entry) => entry.value.trim().toLowerCase() == shortcut)
        .map((entry) => entry.key)
        .firstOrNull;
    if (action == null) return KeyEventResult.ignored;

    final command = switch (action) {
      'newOrder' => AppCommand.newOrder,
      'checkoutCash' => AppCommand.checkoutCash,
      'checkoutCard' => AppCommand.checkoutCard,
      'holdOrder' => AppCommand.holdOrder,
      'focusSearch' => AppCommand.focusSearch,
      _ => null,
    };
    if (command != null) {
      _dependencies?.commandBus.dispatch(command);
      return KeyEventResult.handled;
    }
    if (action == 'logout') {
      _logout();
      return KeyEventResult.handled;
    }
    if (action == 'openManager') {
      final destinations = _destinationsFor(_user!);
      final managerIndex = destinations.indexWhere(
        (destination) => destination.kind == _DestinationKind.manager,
      );
      if (managerIndex >= 0) setState(() => _selectedIndex = managerIndex);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _shortcutFor(LogicalKeyboardKey key) {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final parts = <String>[];
    if (pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight)) {
      parts.add('ctrl');
    }
    if (pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight)) {
      parts.add('alt');
    }
    if (pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight)) {
      parts.add('shift');
    }
    final label = key.keyLabel.trim().toLowerCase();
    if (label.isNotEmpty &&
        !const {'control', 'alt', 'shift'}.contains(label)) {
      parts.add(label);
    }
    return parts.join('+');
  }

  Future<void> _loadCurrentUser() async {
    final user = await AppStateScope.of(context).authRepository.currentUser();
    if (!mounted) return;
    setState(() {
      _user = user;
      _loadingUser = false;
    });
    _resetAutoLock();
  }

  Future<String?> _login(String username, String password) async {
    final dependencies = AppStateScope.of(context);
    final user = await dependencies.authRepository.login(
      username: username,
      password: password,
    );
    if (user == null) {
      return 'اسم المستخدم أو كلمة المرور غير صحيحة.';
    }
    final openShift =
        await dependencies.shiftRepository.getOpenShiftForCashier(user.id);
    if (openShift == null) {
      final now = DateTime.now();
      await dependencies.shiftRepository.saveShift(
        Shift(
          id: 'shift-${user.id}-${now.microsecondsSinceEpoch}',
          cashierId: user.id,
          cashierName: user.displayName,
          cashierCode: user.cashierCode,
          status: ShiftStatus.open,
          openingCash: 0,
          openedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    if (!mounted) return null;
    setState(() {
      _user = user;
      _selectedIndex = 0;
      _locked = false;
    });
    _resetAutoLock();
    return null;
  }

  Future<void> _logout() async {
    _autoLockTimer?.cancel();
    await AppStateScope.of(context).authRepository.logout();
    if (!mounted) return;
    setState(() {
      _user = null;
      _selectedIndex = 0;
      _locked = false;
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

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetAutoLock(),
      onPointerSignal: (_) => _resetAutoLock(),
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) => _handleKeyEvent(event),
        child: Stack(
          children: [
            Scaffold(
              body: Row(
                children: [
                  _Sidebar(
                    user: user,
                    destinations: destinations,
                    selectedIndex: selectedIndex,
                    databaseEnabled: widget.config.database.enabled,
                    onSelected: (index) =>
                        setState(() => _selectedIndex = index),
                    onLogout: _logout,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        _TopTab(destination: destinations[selectedIndex]),
                        Expanded(
                          child: ColoredBox(
                            color: AppTheme.background,
                            child: destinations[selectedIndex].builder(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_locked)
              Positioned.fill(
                child: _PinLockOverlay(
                  user: user,
                  onUnlock: _unlockPin,
                  onLogout: _logout,
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<_ShellDestination> _destinationsFor(AppUser user) {
    return [
      if (user.can(Permission.accessPos))
        _ShellDestination(
          kind: _DestinationKind.pos,
          label: 'نقطة البيع',
          hint: 'إنشاء طلبات وبيع',
          icon: Icons.point_of_sale_outlined,
          selectedIcon: Icons.point_of_sale,
          builder: (_) => PosPage(config: widget.config),
        ),
      if (user.can(Permission.accessManager))
        _ShellDestination(
          kind: _DestinationKind.manager,
          label: 'لوحة التحكم',
          hint: 'ملخص اليوم والإدارة',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          builder: (_) => ManagerPage(config: widget.config),
        ),
      if (user.can(Permission.manageSettings))
        _ShellDestination(
          kind: _DestinationKind.settings,
          label: 'الإعدادات',
          hint: 'اسم المطعم والعملة',
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          builder: (_) => SettingsPage(config: widget.config),
        ),
    ];
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.kind,
    required this.label,
    required this.hint,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });

  final _DestinationKind kind;
  final String label;
  final String hint;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;
}

enum _DestinationKind { pos, manager, settings }

class _PinLockOverlay extends StatefulWidget {
  const _PinLockOverlay({
    required this.user,
    required this.onUnlock,
    required this.onLogout,
  });

  final AppUser user;
  final Future<bool> Function(String pin) onUnlock;
  final VoidCallback onLogout;

  @override
  State<_PinLockOverlay> createState() => _PinLockOverlayState();
}

class _PinLockOverlayState extends State<_PinLockOverlay> {
  String _pin = '';
  bool _checking = false;
  bool _invalid = false;

  Future<void> _press(String digit) async {
    if (_checking || _pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _invalid = false;
    });
    if (_pin.length != 4) return;
    setState(() => _checking = true);
    final valid = await widget.onUnlock(_pin);
    if (!mounted || valid) return;
    setState(() {
      _pin = '';
      _checking = false;
      _invalid = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xF21A1A1A),
      child: Center(
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border.all(color: AppTheme.border, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 42,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 10),
              Text(
                widget.user.displayName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text('Enter PIN to continue'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (index) => Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      color: index < _pin.length
                          ? Theme.of(context).colorScheme.primary
                          : AppTheme.background,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.border, width: 2),
                    ),
                  ),
                ),
              ),
              if (_invalid) ...[
                const SizedBox(height: 10),
                const Text(
                  'Incorrect PIN',
                  style: TextStyle(
                    color: AppTheme.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.6,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final digit in const [
                    '1',
                    '2',
                    '3',
                    '4',
                    '5',
                    '6',
                    '7',
                    '8',
                    '9',
                  ])
                    OutlinedButton(
                      onPressed: _checking ? null : () => _press(digit),
                      child: Text(digit),
                    ),
                  IconButton.outlined(
                    tooltip: 'Delete',
                    onPressed: _checking || _pin.isEmpty
                        ? null
                        : () => setState(
                              () => _pin = _pin.substring(0, _pin.length - 1),
                            ),
                    icon: const Icon(Icons.backspace_outlined),
                  ),
                  OutlinedButton(
                    onPressed: _checking ? null : () => _press('0'),
                    child: const Text('0'),
                  ),
                  IconButton.outlined(
                    tooltip: 'Logout',
                    onPressed: widget.onLogout,
                    icon: const Icon(Icons.logout),
                  ),
                ],
              ),
              if (_checking) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.user,
    required this.destinations,
    required this.selectedIndex,
    required this.databaseEnabled,
    required this.onSelected,
    required this.onLogout,
  });

  final AppUser user;
  final List<_ShellDestination> destinations;
  final int selectedIndex;
  final bool databaseEnabled;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: AppTheme.text,
        border: Border(left: BorderSide(color: brand, width: 3)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: brand, width: 3),
                  bottom: const BorderSide(color: Color(0x26FFFFFF)),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مطعم عبدو كفتة',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'SHIFT POS',
                    style: TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(10),
                itemCount: destinations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 3),
                itemBuilder: (context, index) {
                  final destination = destinations[index];
                  return _SidebarItem(
                    destination: destination,
                    selected: selectedIndex == index,
                    onPressed: () => onSelected(index),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0x26FFFFFF))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DarkStatusChip(
                    label: databaseEnabled
                        ? 'قاعدة البيانات مفعلة'
                        : 'قاعدة البيانات معطلة',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('خروج'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(
                        color: Color(0x80FFFFFF),
                        width: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onPressed,
  });

  final _ShellDestination destination;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        hoverColor: Colors.white.withValues(alpha: 0.10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      destination.hint,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.85)
                            : Colors.white.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopTab extends StatelessWidget {
  const _TopTab({required this.destination});

  final _ShellDestination destination;

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(bottom: BorderSide(color: brand, width: 2)),
      ),
      alignment: Alignment.bottomRight,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Container(
        height: 34,
        constraints: const BoxConstraints(minWidth: 150, maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.background,
          border: Border(
            top: BorderSide(color: brand, width: 2),
            right: BorderSide(color: brand),
            left: BorderSide(color: brand),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(destination.selectedIcon, color: brand, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                destination.label,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkStatusChip extends StatelessWidget {
  const _DarkStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xE6FFFFFF),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
