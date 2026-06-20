import 'app_user.dart';

abstract interface class AuthRepository {
  Future<AppUser?> login({
    required String username,
    required String password,
  });

  Future<void> logout();

  Future<AppUser?> currentUser();
}
