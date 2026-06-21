import '../../../core/database/database_gateway.dart';
import '../../../core/database/database_tables.dart';
import '../../../core/security/password_hasher.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

class SqliteAuthRepository implements AuthRepository {
  SqliteAuthRepository(
    this._database, {
    PasswordHasher passwordHasher = const PasswordHasher(),
  }) : _passwordHasher = passwordHasher;

  final DatabaseGateway _database;
  final PasswordHasher _passwordHasher;
  AppUser? _currentUser;

  Future<void> initialize() async {
    final rows = await _database.query(DatabaseTables.accounts);
    if (rows.isEmpty) {
      await saveAccount(
        AppUser(
          id: 'admin',
          username: 'admin',
          displayName: 'Admin',
          role: UserRole.admin,
          permissions: Permission.values.toSet(),
          cashierCode: 'AD',
        ),
        password: 'password',
      );
      return;
    }
    for (final row in rows) {
      final legacyPin = row['pin'] as String?;
      if (legacyPin == null || legacyPin.isEmpty) continue;
      final user = _userFromRow(row);
      await setPin(user.id, legacyPin);
      await _database.save(
        DatabaseTables.accounts,
        user.id,
        _userToRow(user.copyWith(pin: 'configured')),
      );
    }
  }

  @override
  Future<AppUser?> login({
    required String username,
    required String password,
  }) async {
    final normalized = username.trim();
    if (normalized.isEmpty || password.isEmpty) return null;
    final accounts = await listAccounts();
    AppUser? account;
    for (final candidate in accounts) {
      if (candidate.username.toLowerCase() == normalized.toLowerCase()) {
        account = candidate;
        break;
      }
    }
    if (account == null || !account.active) return null;
    final credentials = await _database.query(
      DatabaseTables.credentials,
      filters: {'id': account.id},
    );
    if (credentials.isEmpty) return null;
    final encoded = credentials.single['passwordHash'] as String?;
    if (encoded == null || !_passwordHasher.verify(password, encoded)) {
      return null;
    }
    _currentUser = account;
    return account;
  }

  @override
  Future<void> logout() async => _currentUser = null;

  @override
  Future<AppUser?> currentUser() async => _currentUser;

  @override
  Future<List<AppUser>> listAccounts() async {
    final rows = await _database.query(DatabaseTables.accounts);
    final accounts = rows.map(_userFromRow).toList();
    accounts.sort((a, b) => a.displayName.compareTo(b.displayName));
    return accounts;
  }

  @override
  Future<AppUser> saveAccount(AppUser user, {String? password}) async {
    final accounts = await listAccounts();
    final duplicate = accounts.any(
      (candidate) =>
          candidate.id != user.id &&
          candidate.username.toLowerCase() == user.username.toLowerCase(),
    );
    if (duplicate) throw StateError('Username already exists');
    await _database.save(DatabaseTables.accounts, user.id, _userToRow(user));
    if (password != null) await setPassword(user.id, password);
    if (_currentUser?.id == user.id) _currentUser = user;
    return user;
  }

  @override
  Future<void> setPassword(String userId, String password) async {
    if (password.length < 6) {
      throw ArgumentError.value(password, 'password', 'Minimum 6 characters');
    }
    final accounts = await _database.query(
      DatabaseTables.accounts,
      filters: {'id': userId},
    );
    if (accounts.isEmpty) throw StateError('Account not found');
    final existing = await _database.query(
      DatabaseTables.credentials,
      filters: {'id': userId},
    );
    await _database.save(
      DatabaseTables.credentials,
      userId,
      {
        if (existing.isNotEmpty) ...existing.single,
        'passwordHash': _passwordHasher.hash(password),
      },
    );
  }

  @override
  Future<void> setPin(String userId, String? pin) async {
    if (pin != null && (pin.length != 4 || int.tryParse(pin) == null)) {
      throw ArgumentError.value(pin, 'pin', 'PIN must contain four digits');
    }
    final accounts = await _database.query(
      DatabaseTables.accounts,
      filters: {'id': userId},
    );
    if (accounts.isEmpty) throw StateError('Account not found');
    final credentials = await _database.query(
      DatabaseTables.credentials,
      filters: {'id': userId},
    );
    final data = <String, Object?>{
      if (credentials.isNotEmpty) ...credentials.single,
    };
    if (pin == null || pin.isEmpty) {
      data.remove('pinHash');
    } else {
      data['pinHash'] = _passwordHasher.hash(pin);
    }
    await _database.save(DatabaseTables.credentials, userId, data);
    final user = _userFromRow(accounts.single);
    await _database.save(
      DatabaseTables.accounts,
      userId,
      _userToRow(user.copyWith(
          pin: pin == null ? null : 'configured', clearPin: pin == null)),
    );
  }

  @override
  Future<bool> verifyPin(String userId, String pin) async {
    final credentials = await _database.query(
      DatabaseTables.credentials,
      filters: {'id': userId},
    );
    final hash =
        credentials.isEmpty ? null : credentials.single['pinHash'] as String?;
    return hash != null && _passwordHasher.verify(pin, hash);
  }

  @override
  Future<void> deleteAccount(String userId) async {
    await _database.delete(DatabaseTables.credentials, userId);
    await _database.delete(DatabaseTables.accounts, userId);
    if (_currentUser?.id == userId) _currentUser = null;
  }

  Map<String, Object?> _userToRow(AppUser user) => {
        'username': user.username,
        'displayName': user.displayName,
        'role': user.role.name,
        'permissions': user.permissions.map((value) => value.name).toList(),
        'cashierCode': user.cashierCode,
        'active': user.active,
        'pinConfigured': user.pin != null,
      };

  AppUser _userFromRow(Map<String, Object?> row) {
    final permissionNames = (row['permissions'] as List<Object?>? ?? const [])
        .whereType<String>()
        .toSet();
    return AppUser(
      id: row['id']! as String,
      username: row['username']! as String,
      displayName: row['displayName']! as String,
      role: UserRole.values.byName(row['role']! as String),
      permissions: Permission.values
          .where((permission) => permissionNames.contains(permission.name))
          .toSet(),
      cashierCode: row['cashierCode'] as String?,
      active: row['active'] as bool? ?? true,
      pin: (row['pinConfigured'] as bool? ?? row['pin'] != null)
          ? 'configured'
          : null,
    );
  }
}
