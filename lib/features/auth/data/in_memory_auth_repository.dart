import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

class InMemoryAuthRepository implements AuthRepository {
  AppUser? _currentUser;

  @override
  Future<AppUser?> login({
    required String username,
    required String password,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) return null;

    _currentUser = AppUser(
      id: 'local-dev-user',
      username: username.trim(),
      displayName: username.trim(),
      role: UserRole.admin,
      permissions: Permission.values.toSet(),
    );

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
}
