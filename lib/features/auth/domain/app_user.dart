class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.permissions,
    this.cashierCode,
    this.active = true,
    this.pin,
  });

  final String id;
  final String username;
  final String displayName;
  final UserRole role;
  final Set<Permission> permissions;
  final String? cashierCode;
  final bool active;
  final String? pin;

  bool can(Permission permission) => permissions.contains(permission);

  AppUser copyWith({
    String? username,
    String? displayName,
    UserRole? role,
    Set<Permission>? permissions,
    String? cashierCode,
    bool? active,
    String? pin,
    bool clearPin = false,
  }) {
    return AppUser(
      id: id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      cashierCode: cashierCode ?? this.cashierCode,
      active: active ?? this.active,
      pin: clearPin ? null : pin ?? this.pin,
    );
  }
}

enum UserRole {
  cashier,
  supervisor,
  manager,
  admin,
}

enum Permission {
  accessPos,
  accessManager,
  manageUsers,
  manageItems,
  manageInventory,
  manageSuppliers,
  viewReports,
  manageSettings,
}
