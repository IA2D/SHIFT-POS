import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository()
      : _accounts = [
          AppUser(
            id: 'admin',
            username: 'admin',
            displayName: 'Admin',
            role: UserRole.admin,
            permissions: Permission.values.toSet(),
            cashierCode: 'AD',
          ),
        ],
        _passwords = {'admin': 'password'},
        _pins = {};

  AppUser? _currentUser;
  final List<AppUser> _accounts;
  final Map<String, String> _passwords;
  final Map<String, String> _pins;

  @override
  Future<AppUser?> login({
    required String username,
    required String password,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) return null;

    final normalized = username.trim();
    AppUser? account;
    for (final candidate in _accounts) {
      if (candidate.username == normalized) {
        account = candidate;
        break;
      }
    }
    if (account != null) {
      if (!account.active || _passwords[account.id] != password) return null;
      _currentUser = account;
      return account;
    }

    _currentUser = AppUser(
      id: 'local-${normalized.toLowerCase()}',
      username: normalized,
      displayName: normalized,
      role: UserRole.admin,
      permissions: Permission.values.toSet(),
    );
    _accounts.add(_currentUser!);
    _passwords[_currentUser!.id] = password;

    return _currentUser;
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
  }

  @override
  Future<AppUser?> currentUser() async {
    return _currentUser;
  }

  @override
  Future<List<AppUser>> listAccounts() async => [..._accounts];

  @override
  Future<AppUser> saveAccount(AppUser user, {String? password}) async {
    final duplicate = _accounts.any(
      (candidate) =>
          candidate.id != user.id && candidate.username == user.username,
    );
    if (duplicate) throw StateError('Username already exists');
    final index = _accounts.indexWhere((candidate) => candidate.id == user.id);
    if (index == -1) {
      _accounts.add(user);
    } else {
      _accounts[index] = user;
      if (_currentUser?.id == user.id) _currentUser = user;
    }
    if (password != null) _passwords[user.id] = password;
    return user;
  }

  @override
  Future<void> setPassword(String userId, String password) async {
    if (password.length < 6) {
      throw ArgumentError.value(password, 'password', 'Minimum 6 characters');
    }
    if (!_accounts.any((account) => account.id == userId)) {
      throw StateError('Account not found');
    }
    _passwords[userId] = password;
  }

  @override
  Future<void> setPin(String userId, String? pin) async {
    if (pin != null && (pin.length != 4 || int.tryParse(pin) == null)) {
      throw ArgumentError.value(pin, 'pin', 'PIN must contain four digits');
    }
    final index = _accounts.indexWhere((account) => account.id == userId);
    if (index == -1) throw StateError('Account not found');
    if (pin == null || pin.isEmpty) {
      _pins.remove(userId);
      _accounts[index] = _accounts[index].copyWith(clearPin: true);
    } else {
      _pins[userId] = pin;
      _accounts[index] = _accounts[index].copyWith(pin: 'configured');
    }
  }

  @override
  Future<bool> verifyPin(String userId, String pin) async =>
      _pins[userId] == pin;

  @override
  Future<void> deleteAccount(String userId) async {
    _accounts.removeWhere((account) => account.id == userId);
    _passwords.remove(userId);
    _pins.remove(userId);
    if (_currentUser?.id == userId) _currentUser = null;
  }
}
