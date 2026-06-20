class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.permissions,
  });

  final String id;
  final String username;
  final String displayName;
  final UserRole role;
  final Set<Permission> permissions;

  bool can(Permission permission) => permissions.contains(permission);
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
